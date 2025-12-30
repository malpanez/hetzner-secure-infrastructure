#!/usr/bin/env python3
"""
WordPress Load Testing Tool
Professional HTTP load testing with detailed metrics
"""

import argparse
import asyncio
import aiohttp
import time
import statistics
from dataclasses import dataclass, field
from typing import List, Dict
from datetime import datetime
import sys


@dataclass
class RequestResult:
    """Individual request result"""
    status: int
    duration_ms: float
    timestamp: float
    error: str = ""


@dataclass
class LoadTestResults:
    """Aggregate load test results"""
    url: str
    total_requests: int
    concurrency: int
    duration_seconds: float

    # Request results
    requests: List[RequestResult] = field(default_factory=list)

    # Success/failure counts
    successful_requests: int = 0
    failed_requests: int = 0

    # Response time statistics (milliseconds)
    min_response_time: float = 0.0
    max_response_time: float = 0.0
    mean_response_time: float = 0.0
    median_response_time: float = 0.0
    p95_response_time: float = 0.0
    p99_response_time: float = 0.0

    # Throughput
    requests_per_second: float = 0.0

    # Status code distribution
    status_codes: Dict[int, int] = field(default_factory=dict)

    def calculate_statistics(self):
        """Calculate aggregate statistics from request results"""
        if not self.requests:
            return

        # Count successes/failures
        self.successful_requests = sum(1 for r in self.requests if 200 <= r.status < 400)
        self.failed_requests = len(self.requests) - self.successful_requests

        # Response times
        durations = [r.duration_ms for r in self.requests]
        self.min_response_time = min(durations)
        self.max_response_time = max(durations)
        self.mean_response_time = statistics.mean(durations)
        self.median_response_time = statistics.median(durations)

        # Percentiles
        sorted_durations = sorted(durations)
        self.p95_response_time = sorted_durations[int(len(sorted_durations) * 0.95)]
        self.p99_response_time = sorted_durations[int(len(sorted_durations) * 0.99)]

        # Throughput
        self.requests_per_second = self.total_requests / self.duration_seconds if self.duration_seconds > 0 else 0

        # Status code distribution
        for req in self.requests:
            self.status_codes[req.status] = self.status_codes.get(req.status, 0) + 1

    def print_report(self):
        """Print formatted test results"""
        print("\n" + "=" * 80)
        print("LOAD TEST RESULTS")
        print("=" * 80)
        print(f"\nTest Configuration:")
        print(f"  URL:              {self.url}")
        print(f"  Total Requests:   {self.total_requests:,}")
        print(f"  Concurrency:      {self.concurrency}")
        print(f"  Test Duration:    {self.duration_seconds:.2f}s")

        print(f"\nRequest Results:")
        print(f"  Successful:       {self.successful_requests:,} ({self.successful_requests/self.total_requests*100:.1f}%)")
        print(f"  Failed:           {self.failed_requests:,} ({self.failed_requests/self.total_requests*100:.1f}%)")
        print(f"  Success Rate:     {self.successful_requests/self.total_requests*100:.1f}%")

        print(f"\nResponse Time Statistics (milliseconds):")
        print(f"  Min:              {self.min_response_time:.2f} ms")
        print(f"  Max:              {self.max_response_time:.2f} ms")
        print(f"  Mean:             {self.mean_response_time:.2f} ms")
        print(f"  Median:           {self.median_response_time:.2f} ms")
        print(f"  95th Percentile:  {self.p95_response_time:.2f} ms")
        print(f"  99th Percentile:  {self.p99_response_time:.2f} ms")

        print(f"\nThroughput:")
        print(f"  Requests/sec:     {self.requests_per_second:.2f}")
        print(f"  Transfer Rate:    {self.requests_per_second * 0.001:.2f} KB/s (estimated)")

        print(f"\nHTTP Status Codes:")
        for status_code in sorted(self.status_codes.keys()):
            count = self.status_codes[status_code]
            percentage = count / self.total_requests * 100
            print(f"  {status_code}:               {count:,} ({percentage:.1f}%)")

        print("\n" + "=" * 80)

        # Performance assessment
        print("\nPerformance Assessment:")
        if self.mean_response_time < 100:
            print("  ✅ Excellent - Mean response time < 100ms")
        elif self.mean_response_time < 300:
            print("  ✅ Good - Mean response time < 300ms")
        elif self.mean_response_time < 1000:
            print("  ⚠️  Acceptable - Mean response time < 1s")
        else:
            print("  ❌ Poor - Mean response time > 1s")

        if self.successful_requests / self.total_requests >= 0.99:
            print("  ✅ Excellent - Success rate ≥ 99%")
        elif self.successful_requests / self.total_requests >= 0.95:
            print("  ⚠️  Good - Success rate ≥ 95%")
        else:
            print("  ❌ Poor - Success rate < 95%")

        if self.requests_per_second >= 100:
            print("  ✅ Excellent - Throughput ≥ 100 req/s")
        elif self.requests_per_second >= 50:
            print("  ✅ Good - Throughput ≥ 50 req/s")
        elif self.requests_per_second >= 10:
            print("  ⚠️  Acceptable - Throughput ≥ 10 req/s")
        else:
            print("  ⚠️  Low - Throughput < 10 req/s")

        print("=" * 80 + "\n")


async def fetch_url(session: aiohttp.ClientSession, url: str, request_num: int, progress_callback=None) -> RequestResult:
    """Fetch a single URL and return timing result"""
    start_time = time.time()

    try:
        async with session.get(url, allow_redirects=True, timeout=aiohttp.ClientTimeout(total=30)) as response:
            await response.read()  # Ensure full response is downloaded
            duration_ms = (time.time() - start_time) * 1000

            if progress_callback:
                progress_callback(request_num)

            return RequestResult(
                status=response.status,
                duration_ms=duration_ms,
                timestamp=start_time
            )
    except asyncio.TimeoutError:
        duration_ms = (time.time() - start_time) * 1000
        if progress_callback:
            progress_callback(request_num)
        return RequestResult(status=0, duration_ms=duration_ms, timestamp=start_time, error="Timeout")
    except Exception as e:
        duration_ms = (time.time() - start_time) * 1000
        if progress_callback:
            progress_callback(request_num)
        return RequestResult(status=0, duration_ms=duration_ms, timestamp=start_time, error=str(e))


async def run_load_test(url: str, total_requests: int, concurrency: int, show_progress: bool = True) -> LoadTestResults:
    """Run load test with specified parameters"""

    results = LoadTestResults(
        url=url,
        total_requests=total_requests,
        concurrency=concurrency,
        duration_seconds=0.0
    )

    # Progress tracking
    completed = [0]
    last_update = [time.time()]

    def progress_callback(request_num):
        completed[0] += 1
        if show_progress and time.time() - last_update[0] >= 0.5:  # Update every 0.5s
            percentage = (completed[0] / total_requests) * 100
            print(f"\rProgress: {completed[0]:,}/{total_requests:,} ({percentage:.1f}%) - "
                  f"{completed[0]/(time.time()-start_time):.1f} req/s", end="", flush=True)
            last_update[0] = time.time()

    print(f"\n{'=' * 80}")
    print(f"Starting load test:")
    print(f"  URL:         {url}")
    print(f"  Requests:    {total_requests:,}")
    print(f"  Concurrency: {concurrency}")
    print(f"{'=' * 80}\n")

    # Configure connection limits
    connector = aiohttp.TCPConnector(limit=concurrency, limit_per_host=concurrency)
    timeout = aiohttp.ClientTimeout(total=30)

    start_time = time.time()

    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        # Create batches to control concurrency
        tasks = []
        for i in range(total_requests):
            task = fetch_url(session, url, i + 1, progress_callback)
            tasks.append(task)

        # Run all requests
        results.requests = await asyncio.gather(*tasks)

    end_time = time.time()
    results.duration_seconds = end_time - start_time

    if show_progress:
        print(f"\rProgress: {total_requests:,}/{total_requests:,} (100.0%) - Complete!{' ' * 20}")

    # Calculate statistics
    results.calculate_statistics()

    return results


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Professional HTTP load testing tool for WordPress",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Light load test
  %(prog)s http://example.com -n 1000 -c 10

  # Heavy load test
  %(prog)s http://example.com -n 10000 -c 100

  # Stress test
  %(prog)s http://example.com -n 50000 -c 500
        """
    )

    parser.add_argument('url', help='Target URL to test')
    parser.add_argument('-n', '--requests', type=int, default=1000,
                      help='Total number of requests (default: 1000)')
    parser.add_argument('-c', '--concurrency', type=int, default=10,
                      help='Number of concurrent requests (default: 10)')
    parser.add_argument('-q', '--quiet', action='store_true',
                      help='Suppress progress output')

    args = parser.parse_args()

    # Validate arguments
    if args.requests < 1:
        print("Error: Number of requests must be at least 1", file=sys.stderr)
        sys.exit(1)

    if args.concurrency < 1:
        print("Error: Concurrency must be at least 1", file=sys.stderr)
        sys.exit(1)

    if args.concurrency > args.requests:
        args.concurrency = args.requests
        print(f"Warning: Concurrency reduced to {args.concurrency} (matches total requests)")

    # Run the load test
    try:
        results = asyncio.run(run_load_test(
            url=args.url,
            total_requests=args.requests,
            concurrency=args.concurrency,
            show_progress=not args.quiet
        ))

        # Print results
        results.print_report()

        # Exit with error code if test failed
        if results.successful_requests / results.total_requests < 0.95:
            sys.exit(1)

    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError running load test: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
