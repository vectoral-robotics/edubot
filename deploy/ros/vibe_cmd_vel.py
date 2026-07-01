#!/usr/bin/env python3
"""Publish /cmd_vel reliably for dashboard Vibe Coding tools."""

import argparse
import sys
import time

import rclpy
from geometry_msgs.msg import Twist
from rclpy.qos import QoSHistoryPolicy, QoSProfile, QoSReliabilityPolicy


def build_twist(speed_x, speed_y, rotation):
    msg = Twist()
    msg.linear.x = speed_x
    msg.linear.y = speed_y
    msg.linear.z = 0.0
    msg.angular.x = 0.0
    msg.angular.y = 0.0
    msg.angular.z = rotation
    return msg


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--topic", default="/cmd_vel")
    parser.add_argument("--speed-x", type=float, required=True)
    parser.add_argument("--speed-y", type=float, required=True)
    parser.add_argument("--rotation", type=float, required=True)
    parser.add_argument("--duration", type=float, required=True)
    parser.add_argument("--rate", type=float, default=20.0)
    parser.add_argument("--wait-subscribers", type=float, default=2.0)
    parser.add_argument("--stop-after", action="store_true")
    args = parser.parse_args()

    if args.duration < 0.0:
        print("duration must be >= 0", file=sys.stderr)
        return 2
    if args.rate <= 0.0:
        print("rate must be > 0", file=sys.stderr)
        return 2

    rclpy.init()
    node = rclpy.create_node("vibe_cmd_vel_publisher")
    qos = QoSProfile(
        reliability=QoSReliabilityPolicy.BEST_EFFORT,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=10,
    )
    publisher = node.create_publisher(Twist, args.topic, qos)

    try:
        deadline = time.monotonic() + args.wait_subscribers
        while publisher.get_subscription_count() == 0 and time.monotonic() < deadline:
            rclpy.spin_once(node, timeout_sec=0.05)

        subscribers = publisher.get_subscription_count()
        if subscribers == 0:
            print(f"no matched subscribers on {args.topic}", file=sys.stderr)
            return 1

        period = 1.0 / args.rate
        count = 0
        msg = build_twist(args.speed_x, args.speed_y, args.rotation)
        end_time = time.monotonic() + args.duration
        while time.monotonic() < end_time:
            publisher.publish(msg)
            count += 1
            rclpy.spin_once(node, timeout_sec=0.0)
            time.sleep(period)

        if args.stop_after:
            stop_msg = build_twist(0.0, 0.0, 0.0)
            for _ in range(4):
                publisher.publish(stop_msg)
                count += 1
                rclpy.spin_once(node, timeout_sec=0.0)
                time.sleep(period)

        print(f"published {count} messages to {args.topic}; matched_subscribers={subscribers}")
        return 0
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
