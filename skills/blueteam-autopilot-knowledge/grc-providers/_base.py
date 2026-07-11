#!/usr/bin/env python3
"""GRC Provider Base Class.

All GRC provider scripts must subclass BaseGRCProvider and implement
the three core methods.

Contract:
    connect()           — Authenticate and validate connectivity.
    list_frameworks()   — List available compliance frameworks as JSON.
    get_framework(id)   — Export a framework's controls as Markdown.

Environment Variables:
    GRC_MODE          — "demo" uses fixture data, unset or "real" uses live API
    GRC_BASE_URL      — Base URL of the GRC platform
    GRC_EMAIL         — Authentication email (if applicable)
    GRC_API_TOKEN     — API token (if pre-configured)
    GRC_VERIFY_SSL    — Whether to verify SSL certificates (default: true)
"""

from __future__ import annotations

import json
import os
import sys
from abc import ABC, abstractmethod
from pathlib import Path


class BaseGRCProvider(ABC):
    """Base class for GRC providers."""

    # Override in subclass
    PROVIDER_NAME: str = "template"
    DISPLAY_NAME: str = "Template Provider"
    DESCRIPTION: str = "Replace with your GRC platform description"

    # Demo fixture data (override in subclass)
    DEMO_FRAMEWORKS: list[dict] = []
    DEMO_FRAMEWORK_CONTENT: str = ""

    def __init__(self):
        self.mode = os.environ.get("GRC_MODE", "")
        self.base_url = os.environ.get("GRC_BASE_URL", "https://localhost:8443")
        self.email = os.environ.get("GRC_EMAIL", "")
        self.api_token = os.environ.get("GRC_API_TOKEN", "")
        self.verify_ssl = os.environ.get("GRC_VERIFY_SSL", "true").lower() in ("true", "1", "yes")

    @abstractmethod
    def connect(self) -> bool:
        """Authenticate with the GRC platform.

        Returns True on success, False on failure.
        """
        ...

    @abstractmethod
    def list_frameworks(self) -> list[dict]:
        """List available compliance frameworks.

        Returns a list of dicts with keys: id, name, type, description.
        """
        ...

    @abstractmethod
    def get_framework(self, library_id: str) -> str:
        """Export a framework's controls as Markdown with YAML frontmatter.

        Args:
            library_id: The unique ID of the framework in the GRC platform.

        Returns:
            Markdown string with YAML frontmatter.
        """
        ...

    def describe(self) -> str:
        """Return a human-readable description of this provider."""
        return (
            f"{self.DISPLAY_NAME}\n"
            f"  {self.DESCRIPTION}\n"
            f"  Provider: {self.PROVIDER_NAME}\n"
            f"  URL: {self.base_url}"
        )


def get_provider(provider_name: str) -> BaseGRCProvider:
    """Dynamically load and instantiate a GRC provider by name.

    Args:
        provider_name: Name of the provider module (e.g., "ciso_assistant")

    Returns:
        An instance of the provider class.

    Raises:
        ImportError: If the provider module cannot be loaded.
        ValueError: If the provider doesn't implement BaseGRCProvider.
    """
    # Convert hyphens to underscores for Python module names
    module_name = provider_name.replace("-", "_")

    # Import from the grc-providers directory
    providers_dir = Path(__file__).parent
    if str(providers_dir) not in sys.path:
        sys.path.insert(0, str(providers_dir))

    try:
        module = __import__(module_name, fromlist=["provider_class"])
    except ImportError as e:
        raise ImportError(f"Cannot load GRC provider '{provider_name}': {e}")

    # Look for a class that extends BaseGRCProvider
    for attr_name in dir(module):
        attr = getattr(module, attr_name)
        if (
            isinstance(attr, type)
            and issubclass(attr, BaseGRCProvider)
            and attr is not BaseGRCProvider
        ):
            return attr()

    raise ValueError(f"Provider '{provider_name}' does not define a BaseGRCProvider subclass")


def list_providers() -> list[str]:
    """List available GRC provider names (excluding _base and __pycache__)."""
    providers_dir = Path(__file__).parent
    providers = []
    for f in providers_dir.iterdir():
        if f.suffix == ".py" and not f.name.startswith("_"):
            providers.append(f.stem.replace("_", "-"))
    return sorted(providers)
