#!/usr/bin/env python3
# /// script
# requires-python = "==3.12.*"
# dependencies = [
#     "dunamai",
# ]
# ///

from dunamai import Version

print(Version.from_git().serialize().replace("+", "_"))
