import contextlib
import importlib.util
import io
import sys
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch


sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "service_watch", Path(__file__).with_name("service-watch.py")
)
assert spec is not None and spec.loader is not None
service_watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(service_watch)


class ServiceWatchTests(unittest.TestCase):
    def test_next_check_is_scheduled_from_cycle_start(self):
        self.assertEqual(service_watch.next_cycle_deadline(100.0), 100.0 + service_watch.INTERVAL)

    def test_audit_flags_globally_open_lan_only_ports(self):
        findings = service_watch.audit_configuration({
            "globally_open_tcp_ports": [80, 2222, 3306],
            "lan_only_tcp_ports": [2222, 3306],
        })
        self.assertEqual([item["code"] for item in findings], ["firewall-lan-only-ports"])
        self.assertEqual(findings[0]["status"], "warn")

    def test_audit_warns_when_ssh_password_authentication_is_enabled(self):
        findings = service_watch.audit_configuration({
            "globally_open_tcp_ports": [],
            "lan_only_tcp_ports": [],
            "ssh_password_authentication": True,
            "ssh_permit_root_login": "no",
        })
        self.assertIn("ssh-password-authentication", [item["code"] for item in findings])

    def test_audit_flags_public_paperless_consumption_directory(self):
        findings = service_watch.audit_configuration({
            "paperless_consumption_dir_is_public": True,
            "globally_open_tcp_ports": [],
            "lan_only_tcp_ports": [],
        })
        self.assertIn("paperless-public-consumption", [item["code"] for item in findings])
        self.assertEqual(
            next(item for item in findings if item["code"] == "paperless-public-consumption")["status"],
            "warn",
        )

    def test_audit_only_warns_about_offline_minecraft_when_enabled(self):
        disabled = service_watch.audit_configuration({
            "minecraft_enabled": False,
            "minecraft_online_mode": False,
            "globally_open_tcp_ports": [],
            "lan_only_tcp_ports": [],
        })
        enabled = service_watch.audit_configuration({
            "minecraft_enabled": True,
            "minecraft_online_mode": False,
            "globally_open_tcp_ports": [],
            "lan_only_tcp_ports": [],
        })
        self.assertNotIn("minecraft-offline-mode", [item["code"] for item in disabled])
        self.assertIn("minecraft-offline-mode", [item["code"] for item in enabled])

    def test_initial_clear_scan_does_not_claim_alerts_recovered(self):
        original_failures = service_watch.State.last_failures
        original_payload = service_watch.State.payload
        output = io.StringIO()
        service_watch.State.last_failures = None
        try:
            with contextlib.redirect_stdout(output):
                service_watch.publish({"checks": [], "audit": []})
            self.assertIn("verificação inicial sem alertas", output.getvalue())
            self.assertNotIn("resolvidos", output.getvalue())
        finally:
            service_watch.State.last_failures = original_failures
            service_watch.State.payload = original_payload

    def test_audit_alert_is_written_to_journal_output(self):
        original_failures = service_watch.State.last_failures
        original_payload = service_watch.State.payload
        output = io.StringIO()
        service_watch.State.last_failures = None
        try:
            with contextlib.redirect_stdout(output):
                service_watch.publish({
                    "checks": [],
                    "audit": [{"message": "firewall requires review"}],
                })
            self.assertIn("firewall requires review", output.getvalue())
        finally:
            service_watch.State.last_failures = original_failures
            service_watch.State.payload = original_payload

    def test_disk_limit_fails_at_threshold(self):
        self.assertEqual(
            service_watch.resource_check("disk /", 90, 90, below=False)["status"],
            "fail",
        )

    def test_available_memory_passes_at_minimum(self):
        self.assertEqual(
            service_watch.resource_check("memory", 10, 10, below=True)["status"],
            "ok",
        )

    def test_http_redirect_counts_as_healthy(self):
        self.assertEqual(service_watch.http_status_check("docs", 302)["status"], "ok")

    def test_redirect_handler_refuses_redirects(self):
        handler = service_watch.NoRedirect()
        request = urllib.request.Request("http://127.0.0.1:1/")
        self.assertIsNone(
            handler.redirect_request(request, None, 302, "Found", {}, "http://127.0.0.1/")
        )

    def test_http_check_does_not_follow_redirect(self):
        result = service_watch.check_http("Paperless", "http://127.0.0.1:1/")
        self.assertEqual(result["status"], "fail")

    def test_http_check_returns_redirect_as_health_status(self):
        class RedirectOpener:
            def open(self, *_args, **_kwargs):
                raise urllib.error.HTTPError(
                    "http://127.0.0.1/", 302, "Found", {}, None
                )

        original = service_watch.HTTP_OPENER
        service_watch.HTTP_OPENER = RedirectOpener()
        try:
            result = service_watch.check_http("Paperless", "http://127.0.0.1/")
        finally:
            service_watch.HTTP_OPENER = original
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["value"], 302)

    def test_health_endpoint_is_loopback_only(self):
        self.assertEqual(service_watch.HEALTH_BIND, "127.0.0.1")
        self.assertEqual(service_watch.PORT, 8091)

    def test_http_handler_uses_cached_snapshot_while_collection_is_blocked(self):
        original_payload = service_watch.State.payload
        service_watch.State.payload = {
            "status": "warn", "summary": "cached snapshot", "checks": [], "audit": []
        }
        server = service_watch.ThreadingHTTPServer((service_watch.HEALTH_BIND, 0), service_watch.Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with patch.object(service_watch, "collect", side_effect=AssertionError("collection blocked")):
                with urllib.request.urlopen(f"http://127.0.0.1:{server.server_port}/health", timeout=2) as response:
                    data = response.read()
            self.assertIn(b"cached snapshot", data)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)
            service_watch.State.payload = original_payload

    def test_poll_once_publishes_snapshot_and_keeps_start_interval(self):
        payload = {"status": "ok", "summary": "fresh", "checks": [], "audit": []}
        with patch.object(service_watch, "collect", return_value=payload) as collect, patch.object(
            service_watch, "publish"
        ) as publish, patch.object(
            service_watch.time, "monotonic", side_effect=[100.0, 110.0]
        ):
            delay = service_watch.poll_once({})
        collect.assert_called_once_with({})
        publish.assert_called_once_with(payload)
        self.assertEqual(delay, service_watch.INTERVAL - 10.0)

    def test_http_server_error_is_unhealthy(self):
        self.assertEqual(service_watch.http_status_check("docs", 503)["status"], "fail")


if __name__ == "__main__":
    unittest.main()
