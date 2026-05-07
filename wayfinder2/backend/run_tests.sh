#!/bin/bash
source .venv/bin/activate
python manage.py check
python manage.py test api.tests.test_data_flow -v 2
