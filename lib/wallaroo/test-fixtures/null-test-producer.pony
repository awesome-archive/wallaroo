use "wallaroo/routing"

class NullTestProducer is Producer
  fun tag receive_credits(credits: ISize, from: Consumer): Producer tag =>
    this

  fun tag log_flushed(low_watermark: SeqId): Producer tag =>
    this

  fun tag update_watermark(route_id: RouteId, seq_id: SeqId): Producer tag =>
    this

  fun ref recoup_credits(credits: ISize) =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): U64 =>
    0

  fun ref _x_resilience_routes(): Routes =>
    Routes

  fun ref _flush(low_watermark: SeqId) =>
    None