import datetime as dt
import unittest
from unittest.mock import patch
import mana_hud as hud


class HudTests(unittest.TestCase):
    def test_session_before_weekly(self):
        metrics = [{"label": "Weekly (7d)"}, {"label": "Codex 5h"}]
        self.assertEqual(sorted(metrics, key=hud.metric_order)[0]["label"], "Codex 5h")

    def test_remaining(self):
        self.assertEqual(hud.remaining(23), 77)
        self.assertEqual(hud.remaining(150), 0)
        self.assertIsNone(hud.remaining(None))

    def test_countdown(self):
        now = dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc)
        self.assertEqual(hud.countdown("2026-01-02T01:02:03Z", now), "1d 01:02:03")
        self.assertEqual(hud.countdown("inválido", now), "reset indisponível")

    def test_missing_executable(self):
        with patch.object(hud.shutil, "which", return_value=None):
            with self.assertRaises(RuntimeError):
                hud.fetch()
            self.assertIsNone(hud.rtk_totals())


if __name__ == "__main__":
    unittest.main()
