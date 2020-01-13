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
use "time"
use "wallaroo_labs/time"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/partitioning"
use "wallaroo/core/data_receiver"
use "wallaroo/core/recovery"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"

class TCPSourceNotify[In: Any val]
  let _source_id: RoutingId
  let _auth: AmbientAuth
  let _msg_id_gen: MsgIdGenerator = MsgIdGenerator
  var _header: Bool = true
  let _pipeline_name: String
  let _source_name: String
  let _handler: FramedSourceHandler[In] val
  let _runner: Runner
  var _router: Router
  let _metrics_reporter: MetricsReporter
  let _header_size: USize
  let _debug: U16 = Log.make_sev_cat(Log.debug(), Log.tcp_source())
  let _info: U16 = Log.make_sev_cat(Log.info(), Log.tcp_source())
  let _err: U16 = Log.make_sev_cat(Log.err(), Log.tcp_source())

  // Watermark
  var _watermark_ts: U64 = 0

  new iso create(source_id: RoutingId, pipeline_name: String, env: Env,
    auth: AmbientAuth, handler: FramedSourceHandler[In] val,
    runner: Runner iso, router': Router, metrics_reporter: MetricsReporter iso)
  =>
    _source_id = source_id
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"
    _auth = auth
    _handler = handler
    _runner = consume runner
    _router = router'
    _metrics_reporter = consume metrics_reporter
    _header_size = _handler.header_length()

  fun routes(): Map[RoutingId, Consumer] val =>
    _router.routes()

  fun ref received(source: TCPSource[In] ref, data: Array[U8] iso,
    consumer_sender: TestableConsumerSender): Bool
  =>
    if _header then
      try
        let payload_size: USize = _handler.payload_length(consume data)?
        source.expect(payload_size)
        _header = false
      else
        Fail()
      end
      true
    else
      _metrics_reporter.pipeline_ingest(_pipeline_name, _source_name)
      let pipeline_time_spent: U64 = 0
      var latest_metrics_id: U16 = 1

      ifdef "trace" then
        @ll(_debug, "Rcvd msg at %s source".cstring(), _pipeline_name.cstring())
      end
      let ingest_ts = WallClock.nanoseconds()
      (let is_finished, let last_ts) =
        try
          let decoded =
            try
              _handler.decode(consume data)?
            else
              ifdef debug then
                @ll(_err, "Error decoding message at source".cstring())
              end
              error
            end
          let decode_end_ts = WallClock.nanoseconds()
          _metrics_reporter.step_metric(_pipeline_name,
            "Decode Time in TCP Source", latest_metrics_id, ingest_ts,
            decode_end_ts)
          latest_metrics_id = latest_metrics_id + 1

          ifdef "trace" then
            @ll(_debug, "Msg decoded at %s source".cstring(), _pipeline_name.cstring())
          end
          let event_ts = _handler.event_time_ns(decoded)
          _watermark_ts = _watermark_ts.max(event_ts)

          if decoded isnt None then
            _runner.run[In](_pipeline_name, pipeline_time_spent, decoded,
              "tcp-source-key", event_ts, _watermark_ts, consumer_sender,
              _router, _msg_id_gen(), None, decode_end_ts, latest_metrics_id,
              ingest_ts)
          else
            (true, ingest_ts)
          end
        else
          @ll(_err, "Unable to decode message at %s source".cstring(), _pipeline_name.cstring())
          ifdef debug then
            Fail()
          end
          (true, ingest_ts)
        end

      if is_finished then
        let end_ts = WallClock.nanoseconds()
        let time_spent = end_ts - ingest_ts // I'm unsure of this stuff

        ifdef "detailed-metrics" then
          _metrics_reporter.step_metric(_pipeline_name,
            "Before end at TCP Source", 9999,
            last_ts, end_ts)
        end

        _metrics_reporter.pipeline_metric(_pipeline_name, time_spent +
          pipeline_time_spent)
        _metrics_reporter.worker_metric(_pipeline_name, time_spent)
      end

      source.expect(_header_size)
      _header = true

      ifdef linux then
        true
      else
        false
      end
    end

  fun ref update_router(router': Router) =>
    _router = router'

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    match _router
    | let p_router: StatePartitionRouter =>
      _router = p_router.update_boundaries(_auth, obs)
    else
      ifdef "trace" then
        @ll(_debug, ("FramedSourceNotify doesn't have StatePartitionRouter." +
          " Updating boundaries is a noop for this kind of Source.")
          .cstring())
      end
    end

  fun ref accepted(source: TCPSource[In] ref) =>
    @ll(_info, "%s: accepted a connection".cstring(), _source_name.cstring())
    _header = true
    source.expect(_header_size)

  fun ref closed(source: TCPSource[In] ref) =>
    @ll(_info, "%s: connection closed\n".cstring(), _source_name.cstring())
