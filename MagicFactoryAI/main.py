"""Magic Factory AI — Application entry point."""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.application import MagicFactoryApp


def main() -> int:
    app = MagicFactoryApp()
    return app.run()


if __name__ == "__main__":
    sys.exit(main())
