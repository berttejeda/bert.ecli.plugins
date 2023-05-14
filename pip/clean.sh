#!/usr/bin/env bash
echo Cleaning up build, pyc, and test artifacts ...
rm -rf .tox/
rm -f .coverage
rm -rf htmlcov/
rm -rf .pytest_cache
find . -name '*.pyc' -exec rm -f {} +
find . -name '*.pyo' -exec rm -f {} +
find . -name '*~' -exec rm -f {} +
find . -name '__pycache__' -exec rm -rf {} +
rm -rf build/
rm -rf dist/
rm -rf .eggs/
find . -name '*.egg-info' -exec rm -rf {} +
find . -name '*.egg' -exec rm -f {} +