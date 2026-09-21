"""Safe local configuration check: never prints credentials or model values."""

import sys

from config import Config


def yes_no(value: bool) -> str:
    return "SÍ" if value else "NO"


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    print(f"AI_API_KEY configurada: {yes_no(bool(Config.AI_API_KEY))}")
    print(f"AI_MODEL configurado: {yes_no(bool(Config.AI_MODEL))}")
    print(f"Provider reconocido: {yes_no(Config.AI_PROVIDER in {'gemini', 'openai'})}")
