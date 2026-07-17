#!/usr/bin/env python3
"""Run the Wonelog API locally."""

from web_app import app

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=False, use_reloader=False)