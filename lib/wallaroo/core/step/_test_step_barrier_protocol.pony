/*

Copyright 2018 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "collections"
use "ponytest"
use "promises"
use "random"
use "time"
use "wallaroo/core/aggregations"
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/time"
use "wallaroo/test_components"


actor _TestStepBarrierProtocol is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_ForwardDataMessagesIfNoBarrier)
    test(_DontForwardDataMessagesIfNotAllBarriers)
    test(_ForwardDataMessagesFromBlockedUpstreamAfterFinalBarrierArrives)
    test(_QueuedBarriersAreSentWhenCompletedLater)

class iso _ForwardDataMessagesIfNoBarrier is UnitTest
  fun name(): String => "step/barrier_protocol/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // Send in data messages to identity computation step
    // Emit those same messages immediately

    // given
    let key = "key"
    let test_finished_msg: USize = -1
    let auth = h.env.root as AmbientAuth
    let expected: Array[(USize | BarrierToken)] val =
      recover [1; 2; 3; 4; 5; 6; 7; 8; 9; 10] end
    let oc = TestOutputCollector[USize](h, test_finished_msg where
      expected_values = expected)
    let step = TestOutputCollectorStepBuilder[USize](h.env, auth, oc)
    let upstream1 = DummyProducer
    let upstream1_id: RoutingId = 1
    let upstream2 = DummyProducer
    let upstream2_id: RoutingId = 2
    step.register_producer(upstream1_id, upstream1)
    step.register_producer(upstream2_id, upstream2)

    // when
    let inputs1: Array[USize] val = recover [1; 2; 3; 4; 5] end
    let inputs2: Array[USize] val = recover [6; 7; 8; 9; 10] end
    TestStepSender[USize].send_seq(inputs1, key, step, upstream1_id,
      upstream1)
    TestStepSender[USize].send_seq(inputs2, key, step, upstream2_id,
      upstream2)

    // then
    // Send last test_finished_message to trigger TestOutputCollector check
    // against expected.
    TestStepSender[USize].send(test_finished_msg, key, step, upstream1_id,
      upstream1)

    h.long_test(1_000_000_000)

class iso _DontForwardDataMessagesIfNotAllBarriers is UnitTest
  fun name(): String =>
    "step/barrier_protocol/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // Send barrier from upstream1 but not from upstream2
    // Send data messages from upstream1, then from upstream2
    // Expect upstream1 data messages were not yet forwarded, since
    // upstream1 should be blocking until upstream2 barrier arrives.
    // The upstream2 data messages should be forwarded.

    // given
    let key = "key"
    let test_finished_msg: USize = -1
    let auth = h.env.root as AmbientAuth
    let token = TestBarrierToken(1)
    let expected: Array[(USize | BarrierToken)] val =
      recover [6; 7; 8; 9; 10] end
    let oc = TestOutputCollector[USize](h, test_finished_msg where
      expected_values = expected)
    let step = TestOutputCollectorStepBuilder[USize](h.env, auth, oc)
    let upstream1 = DummyProducer
    let upstream1_id: RoutingId = 1
    let upstream2 = DummyProducer
    let upstream2_id: RoutingId = 2
    step.register_producer(upstream1_id, upstream1)
    step.register_producer(upstream2_id, upstream2)

    // when
    let inputs1: Array[USize] val = recover [1; 2; 3; 4; 5] end
    let inputs2: Array[USize] val = recover [6; 7; 8; 9; 10] end
    TestStepSender[USize].send_barrier(step, token, upstream1_id, upstream1)
    TestStepSender[USize].send_seq(inputs1, key, step, upstream1_id,
      upstream1)
    TestStepSender[USize].send_seq(inputs2, key, step, upstream2_id,
      upstream2)

    // then
    // Send last test_finished_message to trigger TestOutputCollector check
    // against expected.
    // We have to send this from upstream2 or it won't arrive at our output
    // collector downstream.
    TestStepSender[USize].send(test_finished_msg, key, step, upstream2_id,
      upstream2)

    h.long_test(1_000_000_000)

class iso _ForwardDataMessagesFromBlockedUpstreamAfterFinalBarrierArrives
  is UnitTest
  fun name(): String =>
    "step/barrier_protocol/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // Send barrier from upstream1 but not from upstream2
    // Send data messages from upstream1, then from upstream2
    // Expect upstream1 data messages were not yet forwarded, since
    // upstream1 should be blocking until upstream2 barrier arrives.
    // The upstream2 data messages should be forwarded.

    // given
    let key = "key"
    let test_finished_msg: USize = -1
    let auth = h.env.root as AmbientAuth
    let token = TestBarrierToken(1)
    // These are in reverse order across upstream inputs because the
    // messages from upstream1 will only be forwarded after the barrier
    // from upstream2 is received (and this comes after upstream2's data
    // messages)
    let expected: Array[(USize | BarrierToken)] val =
        recover [6; 7; 8; 9; 10; token; 1; 2; 3; 4; 5] end
    let oc = TestOutputCollector[USize](h, test_finished_msg where
      expected_values = expected)
    let step = TestOutputCollectorStepBuilder[USize](h.env, auth, oc)
    let upstream1 = DummyProducer
    let upstream1_id: RoutingId = 1
    let upstream2 = DummyProducer
    let upstream2_id: RoutingId = 2
    step.register_producer(upstream1_id, upstream1)
    step.register_producer(upstream2_id, upstream2)

    // when
    let inputs1: Array[USize] val = recover [1; 2; 3; 4; 5] end
    let inputs2: Array[USize] val = recover [6; 7; 8; 9; 10] end
    TestStepSender[USize].send_barrier(step, token, upstream1_id, upstream1)
    TestStepSender[USize].send_seq(inputs1, key, step, upstream1_id,
      upstream1)
    TestStepSender[USize].send_seq(inputs2, key, step, upstream2_id,
      upstream2)
    TestStepSender[USize].send_barrier(step, token, upstream2_id, upstream2)

    // then
    // Send last test_finished_message to trigger TestOutputCollector check
    // against expected. We can send this from upstream1 because both
    // upstreams should be unblocked after both barriers arrive.
    TestStepSender[USize].send(test_finished_msg, key, step, upstream1_id,
      upstream1)


    h.long_test(1_000_000_000)

class iso _QueuedBarriersAreSentWhenCompletedLater is UnitTest
  fun name(): String =>
    "step/barrier_protocol/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // Send barrier from upstream1 but not from upstream2
    // Send data messages from upstream1, then from upstream2
    // Expect upstream1 data messages were not yet forwarded, since
    // upstream1 should be blocking until upstream2 barrier arrives.
    // The upstream2 data messages should be forwarded.

    // given
    let key = "key"
    let test_finished_msg: USize = -1
    let auth = h.env.root as AmbientAuth
    let token1 = TestBarrierToken(1)
    let token2 = TestBarrierToken(2)
    // These are in reverse order across upstream inputs because the
    // messages from upstream1 will only be forwarded after the barrier
    // from upstream2 is received (and this comes after upstream2's data
    // messages)
    let expected: Array[(USize | BarrierToken)] val =
        recover [1; 2; token1; 3; token2; 4] end
    let oc = TestOutputCollector[USize](h, test_finished_msg where
      expected_values = expected)
    let step = TestOutputCollectorStepBuilder[USize](h.env, auth, oc)
    let upstream1 = DummyProducer
    let upstream1_id: RoutingId = 1
    let upstream2 = DummyProducer
    let upstream2_id: RoutingId = 2
    step.register_producer(upstream1_id, upstream1)
    step.register_producer(upstream2_id, upstream2)

    // when
    let inputs1a: Array[USize] val = recover [1] end
    let inputs1b: Array[USize] val = recover [3] end
    let inputs2a: Array[USize] val = recover [2] end
    let inputs2b: Array[USize] val = recover [4] end
    // Upstream1 sends a data message, the first token, second data message,
    // and second token. The second token should now be queued.
    TestStepSender[USize].send_seq(inputs1a, key, step, upstream1_id,
      upstream1)
    TestStepSender[USize].send_barrier(step, token1, upstream1_id, upstream1)
    TestStepSender[USize].send_seq(inputs1b, key, step, upstream1_id,
      upstream1)
    TestStepSender[USize].send_barrier(step, token2, upstream1_id, upstream1)
    // Upstream2 sends its data message and tokens.
    TestStepSender[USize].send_seq(inputs2a, key, step, upstream2_id,
      upstream2)
    TestStepSender[USize].send_barrier(step, token1, upstream2_id, upstream2)
    TestStepSender[USize].send_barrier(step, token2, upstream2_id, upstream2)
    TestStepSender[USize].send_seq(inputs2b, key, step, upstream2_id,
      upstream2)

    // then
    // Send last test_finished_message to trigger TestOutputCollector check
    // against expected. We can send this from upstream1 because both
    // upstreams should be unblocked after both barriers arrive.
    TestStepSender[USize].send(test_finished_msg, key, step, upstream1_id,
      upstream1)

    h.long_test(1_000_000_000)
