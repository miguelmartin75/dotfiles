from __future__ import annotations

import hashlib
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import unittest
import uuid
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
WRAPPER = REPO_ROOT / "profiles/common/.local/bin/emacs-agent-event"
HOOKS = REPO_ROOT / "profiles/common/.codex/hooks.json"
LISP_EXPRESSION = "(let ((arguments server-eval-args-left)) (setq server-eval-args-left nil) (unless (= (length arguments) 1) (user-error \"Expected one agent event payload\")) (my/agent-events-ingest (car arguments)))"


class EmacsAgentEventTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.temporary_path = Path(self.temporary_directory.name)
        self.capture_path = self.temporary_path / "emacsclient-argv.json"
        self.client_path = self.temporary_path / "emacsclient"
        self.set_up_client()

    def set_up_client(self) -> None:
        self.client_path.write_text(
            "#!" + sys.executable + "\n"
            "import json\n"
            "import os\n"
            "import sys\n"
            "import time\n"
            "capture_path = os.environ.get('CAPTURE_PATH')\n"
            "if capture_path:\n"
            "    with open(capture_path, 'w') as capture_file:\n"
            "        json.dump(sys.argv[1:], capture_file)\n"
            "sleep_seconds = float(os.environ.get('FAKE_SLEEP', '0'))\n"
            "if sleep_seconds:\n"
            "    time.sleep(sleep_seconds)\n"
            "raise SystemExit(int(os.environ.get('FAKE_EXIT', '0')))\n"
        )
        self.client_path.chmod(0o755)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def call_wrapper(
        self,
        kind: str,
        provider_event: object,
        extra_arguments: list[str] | None = None,
        extra_environment: dict[str, str] | None = None,
        raw_input: str | None = None,
        provider: str = "codex",
    ) -> subprocess.CompletedProcess[str]:
        self.capture_path.unlink(missing_ok=True)
        environment = os.environ.copy()
        environment.pop("EMACS_AGENT_EVENT_SOCKET", None)
        environment.update(
            {
                "PATH": str(self.temporary_path),
                "CAPTURE_PATH": str(self.capture_path),
                "ALTERNATE_EDITOR": "hostile-editor --daemon",
            }
        )
        if extra_environment is not None:
            environment.update(extra_environment)
        command = [
            sys.executable,
            str(WRAPPER),
            "--provider",
            provider,
            "--kind",
            kind,
        ]
        if extra_arguments is not None:
            command.extend(extra_arguments)
        return subprocess.run(
            command,
            input=json.dumps(provider_event) if raw_input is None else raw_input,
            text=True,
            capture_output=True,
            env=environment,
            timeout=10,
        )

    def captured_event(self) -> tuple[list[str], dict[str, object]]:
        arguments = json.loads(self.capture_path.read_text())
        event = json.loads(arguments[-1])
        return arguments, event

    def test_explicit_socket_sends_an_exact_boundary_frame_without_emacsclient(self) -> None:
        socket_path = self.temporary_path / "agent-event.sock"
        event_server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        event_server.bind(str(socket_path))
        event_server.listen(1)
        received_frames: list[bytes] = []
        server_errors: list[OSError] = []

        def receive_event() -> None:
            try:
                connection, _ = event_server.accept()
                with connection:
                    frame = bytearray()
                    while data := connection.recv(4_096):
                        frame.extend(data)
                    received_frames.append(bytes(frame))
            except OSError as error:
                server_errors.append(error)
            finally:
                event_server.close()

        server_thread = threading.Thread(target=receive_event)
        server_thread.start()
        hostile_text = "(progn (delete-file \"important\")) --secret"
        provider_event = {
            "session_id": "session-1",
            "event_id": "event-1",
            "hook_event_name": "ManualFilesChanged",
            "timestamp": "2026-09-04T00:00:00Z",
            "cwd": "/workspace",
            "changed_paths": ["a" * 1_024] * 56,
            "prompt": hostile_text,
            "tool_input": {"command": hostile_text},
        }
        body = "b" * 7_795
        result = self.call_wrapper(
            "files-changed",
            provider_event,
            ["--body", body],
            {"EMACS_AGENT_EVENT_SOCKET": str(socket_path)},
        )
        server_thread.join(timeout=5)

        expected_event = {
            "schema_version": 1,
            "provider": "codex",
            "session_id": "session-1",
            "event_id": "event-1",
            "kind": "files-changed",
            "timestamp": "2026-09-04T00:00:00Z",
            "cwd": "/workspace",
            "title": "Codex reported changed files",
            "body": body,
            "changed_paths": ["a" * 1_024] * 56,
        }
        expected_frame = (
            json.dumps(expected_event, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
            + b"\n"
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertFalse(server_thread.is_alive())
        self.assertEqual(server_errors, [])
        self.assertEqual(received_frames, [expected_frame])
        self.assertEqual(len(received_frames[0]), 65_537)
        self.assertNotIn(hostile_text.encode("utf-8"), received_frames[0])
        self.assertFalse(self.capture_path.exists())

    def test_invalid_and_missing_explicit_sockets_fail_open_without_local_delivery(self) -> None:
        provider_event = {
            "session_id": "session-1",
            "event_id": "event-1",
            "hook_event_name": "Stop",
        }
        invalid_paths = [
            "relative.sock",
            "/tmp//agent-event.sock",
            "/tmp/./agent-event.sock",
            "/tmp/../agent-event.sock",
            "/tmp/~agent-event.sock",
            "/ssh:remote:/agent-event.sock",
            "/C:/agent-event.sock",
            "/tmp/agent-event.sock\nsecond-line",
        ]
        for socket_path in invalid_paths:
            with self.subTest(socket_path=socket_path):
                result = self.call_wrapper(
                    "done",
                    provider_event,
                    ["--hook-name", "Stop"],
                    {"EMACS_AGENT_EVENT_SOCKET": socket_path},
                )
                self.assertEqual(result.returncode, 0)
                self.assertEqual(json.loads(result.stdout), {"continue": True})
                self.assertIn("event rejected", result.stderr)
                self.assertFalse(self.capture_path.exists())

        missing_path = self.temporary_path / "missing.sock"
        missing = self.call_wrapper(
            "done",
            provider_event,
            ["--hook-name", "Stop"],
            {"EMACS_AGENT_EVENT_SOCKET": str(missing_path)},
        )
        self.assertEqual(missing.returncode, 0)
        self.assertEqual(json.loads(missing.stdout), {"continue": True})
        self.assertIn("delivery failed", missing.stderr)
        self.assertFalse(self.capture_path.exists())

    def test_explicit_socket_path_uses_the_100_byte_af_unix_bound(self) -> None:
        provider_event = {
            "session_id": "session-1",
            "event_id": "event-1",
            "hook_event_name": "Stop",
        }
        exact_boundary_path = "/" + "a" * 99
        exact_boundary = self.call_wrapper(
            "done",
            provider_event,
            ["--hook-name", "Stop"],
            {"EMACS_AGENT_EVENT_SOCKET": exact_boundary_path},
        )
        self.assertEqual(len(exact_boundary_path.encode("utf-8")), 100)
        self.assertEqual(exact_boundary.returncode, 0)
        self.assertEqual(json.loads(exact_boundary.stdout), {"continue": True})
        self.assertIn("delivery failed", exact_boundary.stderr)
        self.assertFalse(self.capture_path.exists())

        over_boundary_path = "/" + "a" * 100
        over_boundary = self.call_wrapper(
            "done",
            provider_event,
            ["--hook-name", "Stop"],
            {"EMACS_AGENT_EVENT_SOCKET": over_boundary_path},
        )
        self.assertEqual(len(over_boundary_path.encode("utf-8")), 101)
        self.assertEqual(over_boundary.returncode, 0)
        self.assertEqual(json.loads(over_boundary.stdout), {"continue": True})
        self.assertIn("event rejected", over_boundary.stderr)
        self.assertFalse(self.capture_path.exists())

    def test_stalled_explicit_socket_times_out_without_local_delivery(self) -> None:
        socket_path = self.temporary_path / "stalled-event.sock"
        event_server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        event_server.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1)
        event_server.bind(str(socket_path))
        event_server.listen(1)
        release_server = threading.Event()
        server_errors: list[OSError] = []

        def stall_event_receiver() -> None:
            try:
                connection, _ = event_server.accept()
                with connection:
                    connection.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1)
                    release_server.wait(timeout=5)
            except OSError as error:
                server_errors.append(error)
            finally:
                event_server.close()

        server_thread = threading.Thread(target=stall_event_receiver)
        server_thread.start()
        provider_event = {
            "session_id": "session-1",
            "event_id": "event-1",
            "hook_event_name": "ManualFilesChanged",
            "timestamp": "2026-09-04T00:00:00Z",
            "cwd": "/workspace",
            "changed_paths": ["a" * 1_024] * 56,
        }
        result = self.call_wrapper(
            "files-changed",
            provider_event,
            ["--body", "b" * 7_795],
            {"EMACS_AGENT_EVENT_SOCKET": str(socket_path)},
        )
        release_server.set()
        server_thread.join(timeout=5)

        self.assertEqual(result.returncode, 0)
        self.assertIn("delivery timed out", result.stderr)
        self.assertFalse(server_thread.is_alive())
        self.assertEqual(server_errors, [])
        self.assertFalse(self.capture_path.exists())

    def test_empty_socket_and_remote_context_keep_local_emacsclient_transport(self) -> None:
        result = self.call_wrapper(
            "progress",
            {
                "session_id": "session-1",
                "hook_event_name": "UserPromptSubmit",
                "turn_id": "turn-1",
                "cwd": "/remote/workspace",
            },
            extra_environment={
                "EMACS_AGENT_EVENT_SOCKET": "",
                "HOSTNAME": "remote.example.test",
                "SSH_CONNECTION": "192.0.2.1 22 192.0.2.2 22",
            },
        )

        self.assertEqual(result.returncode, 0)
        arguments, _ = self.captured_event()
        self.assertEqual(arguments[0], "--socket-name=main")

    def test_codex_mappings_discard_prompt_and_tool_input(self) -> None:
        hostile_text = "(progn (delete-file \"important\")) --secret"
        prompt_result = self.call_wrapper(
            "progress",
            {
                "session_id": "session-1",
                "hook_event_name": "UserPromptSubmit",
                "turn_id": "turn-1",
                "prompt": hostile_text,
                "tool_input": {"command": hostile_text},
                "cwd": "/workspace",
            },
        )
        self.assertEqual(prompt_result.returncode, 0)
        self.assertEqual(prompt_result.stdout, "")
        _, prompt_event = self.captured_event()
        self.assertEqual(prompt_event["title"], "Codex is working")
        self.assertEqual(prompt_event["body"], "")
        self.assertNotIn(hostile_text, json.dumps(prompt_event))

        permission_result = self.call_wrapper(
            "attention",
            {
                "session_id": "session-1",
                "hook_event_name": "PermissionRequest",
                "turn_id": "turn-2",
                "tool_input": {"command": hostile_text, "description": hostile_text},
                "cwd": "/workspace",
            },
        )
        self.assertEqual(permission_result.returncode, 0)
        self.assertEqual(permission_result.stdout, "")
        _, permission_event = self.captured_event()
        self.assertEqual(permission_event["title"], "Codex needs approval")
        self.assertEqual(permission_event["body"], "Review the pending approval in Codex.")
        self.assertNotIn(hostile_text, json.dumps(permission_event))

        explicit_error = self.call_wrapper(
            "error",
            {"session_id": "session-1", "hook_event_name": "ManualError"},
            ["--title", "Validation failed", "--body", "Review the test output."],
        )
        self.assertEqual(explicit_error.returncode, 0)
        _, error_event = self.captured_event()
        self.assertEqual(error_event["kind"], "error")
        self.assertEqual(error_event["body"], "Review the test output.")

        changed_files = self.call_wrapper(
            "files-changed",
            {"session_id": "session-1", "hook_event_name": "ManualFilesChanged"},
            ["--changed-path", "src/event.py"],
        )
        self.assertEqual(changed_files.returncode, 0)
        _, files_event = self.captured_event()
        self.assertEqual(files_event["changed_paths"], ["src/event.py"])

    def test_event_ids_preserve_provider_values_hash_discriminators_and_fallback_to_uuid(self) -> None:
        provider_id_result = self.call_wrapper(
            "progress",
            {
                "session_id": "session-1",
                "event_id": "provider-event-id",
                "hook_event_name": "UserPromptSubmit",
                "turn_id": "turn-1",
            },
        )
        self.assertEqual(provider_id_result.returncode, 0)
        _, provider_id_event = self.captured_event()
        self.assertEqual(provider_id_event["event_id"], "provider-event-id")

        deterministic_event = {
            "session_id": "session-2",
            "hook_event_name": "UserPromptSubmit",
            "turn_id": "turn-2",
            "timestamp": "2026-09-04T00:00:00Z",
        }
        self.call_wrapper("progress", deterministic_event)
        _, first_event = self.captured_event()
        self.call_wrapper("progress", deterministic_event)
        _, second_event = self.captured_event()
        expected_id = hashlib.sha256(
            json.dumps(
                ["codex", "session-2", "UserPromptSubmit", "turn-2", "2026-09-04T00:00:00Z"],
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8")
        ).hexdigest()
        self.assertEqual(first_event["event_id"], expected_id)
        self.assertEqual(second_event["event_id"], expected_id)

        uuid_event = {
            "session_id": "session-3",
            "hook_event_name": "UserPromptSubmit",
        }
        self.call_wrapper("progress", uuid_event)
        _, first_uuid_event = self.captured_event()
        self.call_wrapper("progress", uuid_event)
        _, second_uuid_event = self.captured_event()
        self.assertNotEqual(first_uuid_event["event_id"], second_uuid_event["event_id"])
        self.assertEqual(str(uuid.UUID(str(first_uuid_event["event_id"]))), first_uuid_event["event_id"])

    def test_invalid_bounds_and_paths_fail_open_without_delivery(self) -> None:
        oversized_body = self.call_wrapper(
            "error",
            {"session_id": "session-1", "hook_event_name": "Stop"},
            ["--body", "x" * 8_193],
        )
        self.assertEqual(oversized_body.returncode, 0)
        self.assertFalse(self.capture_path.exists())
        self.assertIn("event rejected", oversized_body.stderr)

        traversal_path = self.call_wrapper(
            "files-changed",
            {"session_id": "session-1", "hook_event_name": "Stop"},
            ["--changed-path", "../outside"],
        )
        self.assertEqual(traversal_path.returncode, 0)
        self.assertFalse(self.capture_path.exists())
        self.assertIn("event rejected", traversal_path.stderr)

        invalid_paths = ["", ".", "dir/.", "dir/..", "dir//file", "dir/"]
        for changed_path in invalid_paths:
            with self.subTest(changed_path=changed_path):
                invalid_path = self.call_wrapper(
                    "files-changed",
                    {"session_id": "session-1", "hook_event_name": "Stop"},
                    ["--changed-path", changed_path],
                )
                self.assertEqual(invalid_path.returncode, 0)
                self.assertFalse(self.capture_path.exists())
                self.assertIn("event rejected", invalid_path.stderr)

        oversized_event = self.call_wrapper(
            "files-changed",
            {
                "session_id": "session-1",
                "hook_event_name": "Stop",
                "changed_paths": ["a" * 1_024] * 60,
            },
            ["--body", "b" * 8_192],
        )
        self.assertEqual(oversized_event.returncode, 0)
        self.assertFalse(self.capture_path.exists())
        self.assertIn("event rejected", oversized_event.stderr)

    def test_stop_failures_preserve_the_codex_continuation_contract(self) -> None:
        invalid_inputs = {
            "malformed JSON": "{",
            "oversized input": "x" * 65_537,
            "non-object input": "[]",
        }
        for name, raw_input in invalid_inputs.items():
            with self.subTest(name=name):
                result = self.call_wrapper(
                    "done",
                    {},
                    ["--hook-name", "Stop"],
                    raw_input=raw_input,
                )
                self.assertEqual(result.returncode, 0)
                self.assertEqual(json.loads(result.stdout), {"continue": True})
                self.assertFalse(self.capture_path.exists())
                self.assertIn("event rejected", result.stderr)

    def test_file_observations_are_limited_to_files_changed_events(self) -> None:
        observations: dict[str, object] = {
            "sequence": 0,
            "observed_mtime": 1.5,
            "observed_size": 0,
        }
        accepted = self.call_wrapper(
            "files-changed",
            {
                "session_id": "session-1",
                "hook_event_name": "ManualFilesChanged",
                **observations,
            },
        )
        self.assertEqual(accepted.returncode, 0)
        _, accepted_event = self.captured_event()
        for name, value in observations.items():
            self.assertEqual(accepted_event[name], value)

        for name, value in observations.items():
            with self.subTest(source="provider", name=name):
                rejected = self.call_wrapper(
                    "progress",
                    {
                        "session_id": "session-1",
                        "hook_event_name": "UserPromptSubmit",
                        name: value,
                    },
                )
                self.assertEqual(rejected.returncode, 0)
                self.assertFalse(self.capture_path.exists())
                self.assertIn("event rejected", rejected.stderr)

        null_observation = self.call_wrapper(
            "progress",
            {
                "session_id": "session-1",
                "hook_event_name": "UserPromptSubmit",
                "sequence": None,
            },
        )
        self.assertEqual(null_observation.returncode, 0)
        self.assertFalse(self.capture_path.exists())
        self.assertIn("event rejected", null_observation.stderr)

        argument_observations = {
            "--sequence": "0",
            "--observed-mtime": "1.5",
            "--observed-size": "0",
        }
        for option, value in argument_observations.items():
            with self.subTest(source="argument", option=option):
                rejected = self.call_wrapper(
                    "progress",
                    {
                        "session_id": "session-1",
                        "hook_event_name": "UserPromptSubmit",
                    },
                    [option, value],
                )
                self.assertEqual(rejected.returncode, 0)
                self.assertFalse(self.capture_path.exists())
                self.assertIn("event rejected", rejected.stderr)

    def test_sequences_require_a_real_provider_session_id(self) -> None:
        missing_session = self.call_wrapper(
            "files-changed",
            {"hook_event_name": "ManualFilesChanged", "sequence": 1},
        )
        self.assertEqual(missing_session.returncode, 0)
        self.assertFalse(self.capture_path.exists())
        self.assertIn("event rejected", missing_session.stderr)

        unknown_session = self.call_wrapper(
            "files-changed",
            {
                "session_id": "unknown",
                "hook_event_name": "ManualFilesChanged",
                "sequence": 1,
            },
        )
        self.assertEqual(unknown_session.returncode, 0)
        self.assertFalse(self.capture_path.exists())
        self.assertIn("event rejected", unknown_session.stderr)

        unsequenced_fallback = self.call_wrapper(
            "progress",
            {"hook_event_name": "UserPromptSubmit", "turn_id": "turn-1"},
        )
        self.assertEqual(unsequenced_fallback.returncode, 0)
        _, event = self.captured_event()
        self.assertEqual(event["session_id"], "unknown")

    def test_emacsclient_argv_is_constant_and_ignores_alternate_editor(self) -> None:
        result = self.call_wrapper(
            "progress",
            {
                "session_id": "session-1",
                "hook_event_name": "UserPromptSubmit",
                "turn_id": "turn-1",
                "cwd": "/workspace",
            },
        )
        self.assertEqual(result.returncode, 0)
        arguments, event = self.captured_event()
        self.assertEqual(
            arguments[:-1],
            [
                "--socket-name=main",
                "--alternate-editor=false",
                "--timeout=2",
                "--quiet",
                "--suppress-output",
                "--eval",
                LISP_EXPRESSION,
                "--",
            ],
        )
        self.assertEqual(arguments[-1], json.dumps(event, ensure_ascii=False, separators=(",", ":")))
        self.assertNotIn("hostile-editor", arguments)

    def test_delivery_failures_and_timeout_exit_zero(self) -> None:
        provider_event = {
            "session_id": "session-1",
            "hook_event_name": "UserPromptSubmit",
            "turn_id": "turn-1",
        }
        self.client_path.unlink()
        missing = self.call_wrapper("progress", provider_event)
        self.assertEqual(missing.returncode, 0)
        self.assertIn("emacsclient unavailable", missing.stderr)

        self.set_up_client()
        nonzero = self.call_wrapper(
            "progress", provider_event, extra_environment={"FAKE_EXIT": "1"}
        )
        self.assertEqual(nonzero.returncode, 0)
        self.assertIn("delivery failed", nonzero.stderr)

        timeout = self.call_wrapper(
            "progress", provider_event, extra_environment={"FAKE_SLEEP": "4"}
        )
        self.assertEqual(timeout.returncode, 0)
        self.assertIn("delivery timed out", timeout.stderr)

    def test_stop_and_permission_stdout_preserve_codex_contracts(self) -> None:
        stop = self.call_wrapper(
            "done",
            {
                "session_id": "session-1",
                "hook_event_name": "Stop",
                "turn_id": "turn-1",
                "last_assistant_message": "Completed the focused work.",
            },
            ["--hook-name", "Stop"],
        )
        self.assertEqual(stop.returncode, 0)
        stop_output = json.loads(stop.stdout)
        self.assertEqual(stop_output, {"continue": True})
        self.assertNotIn("decision", stop_output)
        _, stop_event = self.captured_event()
        self.assertEqual(stop_event["body"], "Completed the focused work.")

        permission = self.call_wrapper(
            "attention",
            {
                "session_id": "session-1",
                "hook_event_name": "PermissionRequest",
                "turn_id": "turn-2",
            },
            ["--hook-name", "PermissionRequest"],
        )
        self.assertEqual(permission.returncode, 0)
        self.assertEqual(permission.stdout, "")

        non_stop_done = self.call_wrapper(
            "done",
            {
                "session_id": "session-1",
                "hook_event_name": "UserPromptSubmit",
                "turn_id": "turn-3",
            },
        )
        self.assertEqual(non_stop_done.returncode, 0)
        self.assertEqual(non_stop_done.stdout, "")

        self.client_path.unlink()
        unavailable_stop = self.call_wrapper(
            "done",
            {
                "session_id": "session-1",
                "hook_event_name": "Stop",
                "turn_id": "turn-4",
            },
            ["--hook-name", "Stop"],
        )
        self.assertEqual(unavailable_stop.returncode, 0)
        self.assertEqual(json.loads(unavailable_stop.stdout), {"continue": True})
        self.assertIn("emacsclient unavailable", unavailable_stop.stderr)

    def test_claude_stop_events_use_documented_messages(self) -> None:
        stop = self.call_wrapper(
            "done",
            {
                "session_id": "session-1",
                "hook_event_name": "Stop",
                "last_assistant_message": "Completed the focused work.",
            },
            ["--hook-name", "Stop"],
            provider="claude",
        )
        self.assertEqual(stop.returncode, 0)
        self.assertEqual(stop.stdout, "")
        _, stop_event = self.captured_event()
        self.assertEqual(stop_event["title"], "Claude finished")
        self.assertEqual(stop_event["body"], "Completed the focused work.")

        failure = self.call_wrapper(
            "error",
            {
                "session_id": "session-1",
                "hook_event_name": "StopFailure",
                "error": "rate_limit",
                "last_assistant_message": "API error: rate limit reached",
            },
            ["--hook-name", "StopFailure"],
            provider="claude",
        )
        self.assertEqual(failure.returncode, 0)
        self.assertEqual(failure.stdout, "")
        _, failure_event = self.captured_event()
        self.assertEqual(failure_event["title"], "Claude reported an error")
        self.assertEqual(failure_event["body"], "API error: rate limit reached")

    def test_hooks_are_limited_to_synchronous_notification_events(self) -> None:
        configuration = json.loads(HOOKS.read_text())
        self.assertEqual(set(configuration), {"hooks"})
        hooks = configuration["hooks"]
        self.assertEqual(set(hooks), {"UserPromptSubmit", "PermissionRequest", "Stop"})
        expected_kinds = {
            "UserPromptSubmit": "progress",
            "PermissionRequest": "attention",
            "Stop": "done",
        }
        for event_name, kind in expected_kinds.items():
            groups = hooks[event_name]
            self.assertEqual(len(groups), 1)
            handlers = groups[0]["hooks"]
            self.assertEqual(len(handlers), 1)
            handler = handlers[0]
            self.assertEqual(handler["type"], "command")
            self.assertEqual(handler["timeout"], 3)
            self.assertNotIn("async", handler)
            self.assertIn("emacs-agent-event", handler["command"])
            self.assertIn(f"--kind {kind}", handler["command"])
            self.assertIn(f"--hook-name {event_name}", handler["command"])
            self.assertNotIn("decision", handler)


if __name__ == "__main__":
    unittest.main()
