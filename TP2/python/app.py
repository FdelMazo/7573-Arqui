from flask import Flask, jsonify, make_response
from time import sleep

app = Flask(__name__)


@app.route("/")
def root():
    response = make_response("Hi, I'm root")
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    return response


@app.route("/sleep")
@app.route("/sleep/<int:id>")
def slow(id=None):
    sleep(0.75)
    response = jsonify({'id': id})
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    return response


if __name__ == "__main__":
    app.run()
