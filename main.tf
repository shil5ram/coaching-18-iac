import os
import boto3
from flask import Flask, request, jsonify

app = Flask(__name__)


def get_s3_client():
    return boto3.client('s3')


@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({"error": "No file part in the request"}), 400

    file = request.files['file']
    if file.filename in (None, ''):
        return jsonify({"error": "No selected file"}), 400

    bucket_name = os.environ.get('S3_BUCKET_NAME')
    if not bucket_name:
        return jsonify({"error": "S3 bucket is not configured"}), 500

    try:
        file.stream.seek(0)
        s3_client = get_s3_client()
        s3_client.upload_fileobj(file.stream, bucket_name, file.filename)
        return jsonify({"message": f"Successfully uploaded {file.filename} to S3."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
