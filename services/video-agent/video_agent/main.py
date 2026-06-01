from __future__ import annotations

import argparse
import logging
import time

from .agent import VideoAgent
from .config import load_config
from .events import discover_local_media, parse_gcs_notification


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Smart City video safety inference agent")
    parser.add_argument("--once", action="store_true", help="process available work once, then exit")
    parser.add_argument("--local-scan", action="store_true", help="scan VIDEO_AGENT_INPUT_DIR instead of Pub/Sub")
    parser.add_argument("--gcs-event-json", help="process one Cloud Storage notification JSON payload")
    return parser


def run_local_once(agent: VideoAgent) -> int:
    cfg = agent.config
    events = discover_local_media(cfg.input_dir, cfg.city, cfg.camera_id)
    count = 0
    for event in events:
        count += len(agent.process_event(event))
    logging.getLogger("video-agent").info("processed local media=%d flags=%d", len(events), count)
    return count


def run_pubsub_once(agent: VideoAgent) -> int:
    from google.cloud import pubsub_v1

    cfg = agent.config
    if not cfg.gcs_bucket:
        raise ValueError("VIDEO_AGENT_GCS_BUCKET or GCS_BUCKET must be set for Pub/Sub mode")
    subscriber = pubsub_v1.SubscriberClient()
    project = cfg.pubsub_subscription.split("/")[1] if cfg.pubsub_subscription.startswith("projects/") else None
    subscription_path = cfg.pubsub_subscription
    if not subscription_path.startswith("projects/"):
        import os

        project = os.getenv("GCP_PROJECT_ID")
        if not project:
            raise ValueError("GCP_PROJECT_ID is required when VIDEO_AGENT_PUBSUB_SUBSCRIPTION is not a full path")
        subscription_path = subscriber.subscription_path(project, cfg.pubsub_subscription)

    flags = 0
    response = subscriber.pull(subscription=subscription_path, max_messages=10, timeout=30)
    ack_ids = []
    for received in response.received_messages:
        event = parse_gcs_notification(received.message.data, cfg.city, cfg.camera_id)
        flags += len(agent.process_event(event))
        ack_ids.append(received.ack_id)
    if ack_ids:
        subscriber.acknowledge(subscription=subscription_path, ack_ids=ack_ids)
    return flags


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    args = build_parser().parse_args()
    cfg = load_config()
    agent = VideoAgent(cfg)
    try:
        if args.gcs_event_json:
            event = parse_gcs_notification(args.gcs_event_json, cfg.city, cfg.camera_id)
            return 0 if agent.process_event(event) else 1
        if args.local_scan or args.once:
            run_local_once(agent)
            return 0
        while True:
            run_pubsub_once(agent)
            time.sleep(cfg.poll_seconds)
    finally:
        agent.close()


if __name__ == "__main__":
    raise SystemExit(main())
