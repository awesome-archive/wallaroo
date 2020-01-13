/*

Copyright 2017 The Wallaroo Authors.

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
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/metrics"
use "wallaroo/core/rebalancing"
use "wallaroo/core/recovery"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"


trait StepPhase
  fun name(): String

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref trigger_timeout(step: Step ref) =>
    """
    We trigger in all cases unless we're disposed.
    """
    step.finish_triggering_timeout()

  fun ref receive_new_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _invalid_call(__loc.method_name()); Fail()

  fun ref prepare_for_rollback(token: BarrierToken) =>
    """
    If we're not handling a barrier, there's nothing to do to prepare.
    """
    None

  fun ref rollback(step_id: RoutingId, step: Step ref, payload: ByteSeq val,
    event_log: EventLog, runner: Runner)
  =>
    """
    If we haven't been disposed, rollback overrides any state we might be in.
    """
    ifdef "resilience" then
      StepRollbacker(payload, runner, step)
    end
    event_log.ack_rollback(step_id)
    step.finish_rolling_back()

  fun ref remove_input(input_id: RoutingId) =>
    """
    We only manage inputs if we're handling a barrier.
    """
    None

  fun ref check_completion(inputs: Map[RoutingId, Producer] box) =>
    """
    We only do anything on a completion check if we're handling a
    barrier.
    """
    None

  fun ref queued(): Array[_Queued] =>
    _invalid_call(__loc.method_name()); Fail()
    Array[_Queued]

  fun send_state(step: Step ref, runner: Runner, id: RoutingId,
    boundary: OutgoingBoundary, step_group: RoutingId, key: Key,
    checkpoint_id: CheckpointId, auth: AmbientAuth)
  =>
    """
    We should only be sending state in normal processing mode.
    """
    _invalid_call(__loc.method_name()); Fail()

  fun ref dispose(step: Step ref) =>
    step.finish_disposing()

  fun _invalid_call(method_name: String) =>
    @printf[I32]("Invalid call to %s on step phase %s\n".cstring(),
      method_name.cstring(), name().cstring())

class _InitialStepPhase is StepPhase
  fun name(): String => __loc.type_name()

class _NormalStepPhase is StepPhase
  let _step: Step ref

  new create(s: Step ref) =>
    _step = s

  fun name(): String => __loc.type_name()

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64)
  =>
    _step.process_message[D](metric_name, pipeline_time_spent, data, key,
      event_ts, watermark_ts, i_producer_id, i_producer, msg_uid, frac_ids,
      i_seq_id, latest_ts, metrics_id, worker_ingress_ts)

  fun ref receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _step.receive_new_barrier(step_id, producer, barrier_token)

  fun send_state(step: Step ref, runner: Runner, id: RoutingId,
    boundary: OutgoingBoundary, step_group: RoutingId, key: Key,
    checkpoint_id: CheckpointId, auth: AmbientAuth)
  =>
    StepStateMigrator.send_state(step, runner, id, boundary, step_group,
      key, checkpoint_id, auth)

  fun ref queued(): Array[_Queued] =>
    Array[_Queued]

type _Queued is (QueuedMessage | QueuedBarrier)


class _BarrierStepPhase is StepPhase
  let _step: Step ref
  let _step_id: RoutingId
  let _barrier_token: BarrierToken
  let _inputs_blocking: Map[RoutingId, Producer] = _inputs_blocking.create()
  let _removed_inputs: SetIs[RoutingId] = _removed_inputs.create()
  var _queued: Array[_Queued] = _queued.create()

  new create(s: Step ref, s_id: RoutingId, token: BarrierToken) =>
    _step = s
    _step_id = s_id
    _barrier_token = token

  fun name(): String => __loc.type_name()

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64)
  =>
    if input_blocking(i_producer_id) then
      let msg = TypedQueuedMessage[D](metric_name, pipeline_time_spent,
        data, key, event_ts, watermark_ts, i_producer_id, i_producer, msg_uid,
        frac_ids, i_seq_id, latest_ts, metrics_id, worker_ingress_ts)
      _queued.push(msg)
    else
      _step.process_message[D](metric_name, pipeline_time_spent, data, key,
        event_ts, watermark_ts, i_producer_id, i_producer, msg_uid, frac_ids,
        i_seq_id, latest_ts, metrics_id, worker_ingress_ts)
    end

  fun ref queued(): Array[_Queued] =>
    let qd = Array[_Queued]
    for q in _queued.values() do
      qd.push(q)
    end
    qd

  fun ref higher_priority(token: BarrierToken): Bool =>
    token > _barrier_token

  fun input_blocking(id: RoutingId): Bool =>
    _inputs_blocking.contains(id)

  fun ref receive_barrier(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    //If we are processing a "high priority" barrier (such as a Rollback
    //barrier), we should throw away any lower priority barriers we see as
    //it is expected they might still be in circulation.
    if _barrier_token > barrier_token then
      return
    end

    if input_blocking(input_id) then
      _queued.push(QueuedBarrier(input_id, producer, barrier_token))
    else
      ifdef debug then
        if barrier_token > _barrier_token then
          @printf[I32](("Invariant violation: received barrier %s is " +
            "greater than current barrier %s at Step %s\n").cstring(),
            barrier_token.string().cstring(),
            _barrier_token.string().cstring(), _step_id.string().cstring())
        end

        Invariant(not (barrier_token > _barrier_token))
      end

      ifdef debug then
        if barrier_token != _barrier_token then
          @printf[I32]("Received %s when still processing %s at step %s\n"
            .cstring(), barrier_token.string().cstring(),
            _barrier_token.string().cstring(), _step_id.string().cstring())
          Fail()
        end
      end

      let inputs = _step.inputs()
      if inputs.contains(input_id) then
        _inputs_blocking(input_id) = producer
        check_completion(inputs)
      else
        if not _removed_inputs.contains(input_id) then
          @printf[I32]("%s: Step %s doesn't know about %s\n".cstring(),
            barrier_token.string().cstring(), _step_id.string().cstring(),
            input_id.string().cstring())
          Fail()
        end
      end
    end

  fun ref prepare_for_rollback(token: BarrierToken) =>
    if higher_priority(token) then
      _step.finish_preparing_for_rollback()
    end

  fun ref remove_input(input_id: RoutingId) =>
    """
    Called if an input leaves the system during barrier processing. This should
    only be possible with Sources that are closed (e.g. when a TCPSource
    connection is dropped).
    """
    if _inputs_blocking.contains(input_id) then
      try
        _inputs_blocking.remove(input_id)?
      else
        Unreachable()
      end
    end
    _removed_inputs.set(input_id)
    if _inputs_blocking.contains(input_id) then
      try _inputs_blocking.remove(input_id)? else Unreachable() end
    end
    check_completion(_step.inputs())

  fun ref check_completion(inputs: Map[RoutingId, Producer] box) =>
    if inputs.size() == _inputs_blocking.size()
    then
      for (o_id, o) in _step.outputs().pairs() do
        match o
        | let ob: OutgoingBoundary =>
          ob.forward_barrier(o_id, _step_id,
            _barrier_token)
        else
          o.receive_barrier(_step_id, _step, _barrier_token)
        end
      end
      let b_token = _barrier_token
      _step.barrier_complete(b_token)
    end

class _RecoveringStepPhase is StepPhase
  let _step: Step ref
  let _token: (CheckpointRollbackBarrierToken | None)

  new create(s: Step ref,
    token: (CheckpointRollbackBarrierToken | None) = None)
  =>
    _step = s
    _token = token

  fun name(): String => __loc.type_name()

  fun ref higher_priority(token: BarrierToken): Bool =>
    match _token
    | let b: BarrierToken =>
      token > b
    else
      true
    end

  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64)
  =>
    None

  fun ref trigger_timeout(step: Step ref) =>
    None

  fun ref receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    @printf[I32]("Ignoring non-rollback barrier %s in _RecoveringStepPhase\n"
      .cstring(), barrier_token.string().cstring())

  fun ref prepare_for_rollback(token: BarrierToken) =>
    if higher_priority(token) then
      _step.finish_preparing_for_rollback()
    end

  fun ref queued(): Array[_Queued] =>
    Array[_Queued]

  fun send_state(step: Step ref, runner: Runner, id: RoutingId,
    boundary: OutgoingBoundary, step_group: RoutingId, key: Key,
    checkpoint_id: CheckpointId, auth: AmbientAuth)
  =>
    None

class _DisposedStepPhase is StepPhase
  fun ref run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, key: Key, event_ts: U64, watermark_ts: U64,
    i_producer_id: RoutingId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, latest_ts: U64,
    metrics_id: U16, worker_ingress_ts: U64)
  =>
    None

  fun name(): String => __loc.type_name()

  fun ref trigger_timeout(step: Step ref) =>
    None

  fun ref receive_new_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    None

  fun ref receive_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    None

  fun ref queued(): Array[_Queued] =>
    Array[_Queued]

  fun send_state(step: Step ref, runner: Runner, id: RoutingId,
    boundary: OutgoingBoundary, step_group: RoutingId, key: Key,
    checkpoint_id: CheckpointId, auth: AmbientAuth)
  =>
    None

  fun ref rollback(step_id: RoutingId, step: Step ref, payload: ByteSeq val,
    event_log: EventLog, runner: Runner)
  =>
    None

  fun ref dispose(step: Step ref) =>
    None
