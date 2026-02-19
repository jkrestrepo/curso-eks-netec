import os, time
import boto3

QUEUE_URL = os.environ["QUEUE_URL"]
REGION = os.environ.get("AWS_REGION", "us-east-1")
SLEEP_SECS = int(os.environ.get("PROCESS_SECONDS", "2"))

sqs = boto3.client("sqs", region_name=REGION)
print(f"[worker] starting. region={REGION} queue={QUEUE_URL} process_seconds={SLEEP_SECS}")

while True:
    resp = sqs.receive_message(
        QueueUrl=QUEUE_URL,
        MaxNumberOfMessages=10,
        WaitTimeSeconds=20,         # long polling
        VisibilityTimeout=30
    )
    msgs = resp.get("Messages", [])
    if not msgs:
        print("[worker] no messages")
        continue

    for m in msgs:
        body = (m.get("Body") or "")[:200]
        rh = m["ReceiptHandle"]
        print(f"[worker] got message: {body}")
        time.sleep(SLEEP_SECS)
        sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=rh)
        print("[worker] deleted message")
