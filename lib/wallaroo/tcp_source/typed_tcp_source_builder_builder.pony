use "wallaroo/metrics"
use "wallaroo/source"
use "wallaroo/topology"

class val TypedTCPSourceBuilderBuilder[In: Any val]
  let _app_name: String
  let _name: String
  let _handler: FramedSourceHandler[In] val
  let _host: String
  let _service: String

  new val create(app_name: String, name': String,
    handler: FramedSourceHandler[In] val, host': String, service': String)
  =>
    _app_name = app_name
    _name = name'
    _handler = handler
    _host = host'
    _service = service'

  fun name(): String => _name

  fun apply(runner_builder: RunnerBuilder, router: Router,
    metrics_conn: MetricsSink, pre_state_target_id: (U128 | None) = None,
    worker_name: String, metrics_reporter: MetricsReporter iso):
      SourceBuilder
  =>
    BasicSourceBuilder[In, FramedSourceHandler[In] val](_app_name, worker_name,
      _name, runner_builder, _handler, router,
      metrics_conn, pre_state_target_id, consume metrics_reporter,
      TCPFramedSourceNotifyBuilder[In])

  fun host(): String =>
    _host

  fun service(): String =>
    _service