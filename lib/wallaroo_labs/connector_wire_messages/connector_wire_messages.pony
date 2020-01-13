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

use "buffered"
use col = "collections"

// Frame types

primitive FrameTag
  fun decode(rb: Reader): Message ? =>
    let frame_tag = rb.u8()?
    match frame_tag
    | 0 => HelloMsg.decode(rb)?
    | 1 => OkMsg.decode(consume rb)?
    | 2 => ErrorMsg.decode(consume rb)?
    | 3 => NotifyMsg.decode(consume rb)?
    | 4 => NotifyAckMsg.decode(consume rb)?
    | 5 => MessageMsg.decode(consume rb)?
    | 6 => AckMsg.decode(consume rb)?
    | 7 => RestartMsg.decode(consume rb)?
    | 8 => EosMessageMsg.decode(consume rb)?
    | 9 => WorkersLeftMsg.decode(consume rb)?
    else
      error
    end

  fun apply(msg: Message): U8 =>
    match msg
    | let m: HelloMsg => 0
    | let m: OkMsg => 1
    | let m: ErrorMsg => 2
    | let m: NotifyMsg => 3
    | let m: NotifyAckMsg => 4
    | let m: MessageMsg => 5
    | let m: AckMsg => 6
    | let m: RestartMsg => 7
    | let m: EosMessageMsg => 8
    | let m: WorkersLeftMsg => 9
    end

// Framing
type StreamId is U64
type StreamName is String
type PointOfRef is U64
type Credit is (StreamId, StreamName, PointOfRef)
type EventTimeType is I64
type MessageId is U64
type MessageBytes is ByteSeq
type KeyBytes is ByteSeq
type WorkerName is String
// TODO [post-source-migration]: deprecate these types
type SourceName is String
type SourceAddress is String
type SourceList is Array[(SourceName, SourceAddress)] val


type Message is ( HelloMsg |
                  OkMsg |
                  ErrorMsg |
                  NotifyMsg |
                  NotifyAckMsg |
                  MessageMsg |
                  EosMessageMsg |
                  AckMsg |
                  RestartMsg |
                  WorkersLeftMsg)

trait MessageTrait
  fun encode(wb: Writer = Writer): Writer ?
  new decode(rb: Reader) ?

primitive Frame
  fun encode(msg: Message, wb: Writer = Writer): Array[U8] val =>
    let encoded = msg.encode()
    wb.u8(FrameTag(msg))
    wb.writev(encoded.done())
    let bs: Array[ByteSeq val] val = wb.done()
    recover
      let a = Array[U8]
      for b in bs.values() do
        a.append(b)
      end
      a
    end

  fun decode(data: Array[U8] val): Message ? =>
    // read length
    let rb = Reader
    rb.append(data)
    FrameTag.decode(consume rb)?


class HelloMsg is MessageTrait
  let version: String
  let cookie: String
  let program_name: String
  let instance_name: String

  new create(version': String, cookie': String, program_name': String,
    instance_name': String)
  =>
    version = version'
    cookie = cookie'
    program_name = program_name'
    instance_name = instance_name'

  new decode(rb: Reader) ? =>
    var length = rb.u16_be()?.usize()
    version = String.from_array(rb.block(length)?)
    length = rb.u16_be()?.usize()
    cookie = String.from_array(rb.block(length)?)
    length = rb.u16_be()?.usize()
    program_name = String.from_array(rb.block(length)?)
    length = rb.u16_be()?.usize()
    instance_name = String.from_array(rb.block(length)?)

  fun encode(wb: Writer = Writer): Writer =>
    wb.u16_be(version.size().u16())
    wb.write(version)
    wb.u16_be(cookie.size().u16())
    wb.write(cookie)
    wb.u16_be(program_name.size().u16())
    wb.write(program_name)
    wb.u16_be(instance_name.size().u16())
    wb.write(instance_name)
    wb

class OkMsg is MessageTrait
  let initial_credits: U32

  new create(initial_credits': U32)
  =>
    initial_credits = initial_credits'

  new decode(rb: Reader) ? =>
    initial_credits = rb.u32_be()?

  fun encode(wb: Writer = Writer): Writer =>
    wb.u32_be(initial_credits)
    wb

class ErrorMsg is MessageTrait
  let message: String

  new create(message': String) =>
    message = message'

  new decode(rb: Reader)? =>
    let length = rb.u16_be()?.usize()
    message = String.from_array(rb.block(length)?)

  fun encode(wb: Writer = Writer): Writer =>
    wb.u16_be(message.size().u16())
    wb.write(message)
    wb

class NotifyMsg is MessageTrait
  let stream_id: StreamId
  let stream_name: StreamName
  let point_of_ref: PointOfRef

  new create(stream_id': StreamId, stream_name': StreamName,
    point_of_ref': PointOfRef)
  =>
    stream_id = stream_id'
    stream_name = stream_name'
    point_of_ref = point_of_ref'

  new decode(rb: Reader) ? =>
    stream_id = rb.u64_be()?
    let length = rb.u16_be()?.usize()
    stream_name = String.from_array(rb.block(length)?)
    point_of_ref = rb.u64_be()?

  fun encode(wb: Writer = Writer): Writer =>
    wb.u64_be(stream_id)
    wb.u16_be(stream_name.size().u16())
    wb.write(stream_name)
    wb.u64_be(point_of_ref)
    wb

class NotifyAckMsg is MessageTrait
  let success: Bool
  let stream_id: StreamId
  let point_of_ref: PointOfRef

  new create(success': Bool, stream_id': StreamId, point_of_ref': PointOfRef) =>
    success = success'
    stream_id = stream_id'
    point_of_ref = point_of_ref'

  new decode(rb: Reader) ? =>
    success = if rb.u8()? == 1 then true else false end
    stream_id = rb.u64_be()?
    point_of_ref = rb.u64_be()?

  fun encode(wb: Writer = Writer): Writer =>
    if success then wb.u8(1) else wb.u8(0) end
    wb.u64_be(stream_id)
    wb.u64_be(point_of_ref)
    wb

class MessageMsg is MessageTrait
  let stream_id: StreamId
  let message_id: MessageId
  let event_time: EventTimeType
  let key: (KeyBytes | None)
  let message: (MessageBytes | ByteSeqIter | None)

  new create(
    stream_id': StreamId,
    message_id': MessageId,
    event_time': EventTimeType,
    key': (KeyBytes | None) = None,
    message': (MessageBytes | ByteSeqIter | None) = None)
  =>
    stream_id = stream_id'
    message_id = message_id'
    event_time = event_time'
    key = key'
    message = message'



  new decode(rb: Reader) ? =>
    stream_id = rb.u64_be()?
    message_id = rb.u64_be()?

    event_time = rb.i64_be()?

    let key_length = rb.u16_be()?.usize()
    key =
      if key_length != 0 then
        rb.block(key_length)?
      else
        None
      end
    message = rb.block(rb.size())?

  fun encode(wb: Writer = Writer): Writer =>
    wb.u64_be(stream_id)

    wb.u64_be(message_id)

    wb.i64_be(event_time)

    match key
    | None =>
      wb.u16_be(U16(0))
    | let kb: KeyBytes =>
      wb.u16_be(kb.size().u16())
      wb.write(kb)
    end

    match message
    | let mb: MessageBytes => wb.write(mb)
    | let bs: ByteSeqIter => wb.writev(bs)
    end
    wb

class EosMessageMsg is MessageTrait
  let stream_id: StreamId

  new create(
    stream_id': StreamId)
  =>
    stream_id = stream_id'

  new decode(rb: Reader) ? =>
    stream_id = rb.u64_be()?

  fun encode(wb: Writer = Writer): Writer =>
    wb.u64_be(stream_id)
    wb

class AckMsg is MessageTrait
  let credits: U32
  let credit_list: Array[(StreamId, PointOfRef)] val

  new create(credits': U32, credit_list': Array[(StreamId, PointOfRef)] val) =>
    credits = credits'
    credit_list = credit_list'

  new decode(rb: Reader) ? =>
    credits = rb.u32_be()?
    let cl_size = rb.u32_be()?.usize()
    let cl = recover iso Array[(StreamId, PointOfRef)] end
    for x in col.Range(0, cl_size) do
      cl.push((rb.u64_be()?, rb.u64_be()?))
    end
    credit_list = consume cl


  fun encode(wb: Writer = Writer): Writer =>
    wb.u32_be(credits)
    wb.u32_be(credit_list.size().u32())
    for cr in credit_list.values() do
      wb.u64_be(cr._1)
      wb.u64_be(cr._2)
    end
    wb

class RestartMsg is MessageTrait
  let address: String

  new create(address': String) =>
    address = address'

  fun encode(wb: Writer = Writer): Writer =>
    wb.u32_be(address.size().u32())
    wb.write(address)
    wb

  new decode(rb: Reader) ? =>
    let a_size = rb.u32_be()?.usize()
    address = String.from_array(rb.block(a_size)?)

// 2PC messages

type TwoPCMessage is ( ListUncommittedMsg |
                       ReplyUncommittedMsg |
                       TwoPCPhase1Msg |
                       TwoPCReplyMsg |
                       TwoPCPhase2Msg |
                       WorkersLeftMsg )

primitive TwoPCFrame
  fun encode(msg: TwoPCMessage, wb: Writer = Writer): Array[U8] val =>
    let encoded = msg.encode()
    wb.u8(TwoPCFrameTag(msg))
    wb.writev(encoded.done())
    let bs: Array[ByteSeq val] val = wb.done()
    recover
      let a = Array[U8]
      for b in bs.values() do
        a.append(b)
      end
      a
    end

  fun decode(data: Array[U8] val): TwoPCMessage ? =>
    // read length
    let rb = Reader
    rb.append(data)
    TwoPCFrameTag.decode(consume rb)?

primitive TwoPCFrameTag
  fun decode(rb: Reader): TwoPCMessage ? =>
    let frame_tag = rb.u8()?
    match frame_tag
    | 201 => ListUncommittedMsg.decode(rb)?
    | 202 => ReplyUncommittedMsg.decode(consume rb)?
    | 203 => TwoPCPhase1Msg.decode(consume rb)?
    | 204 => TwoPCReplyMsg.decode(consume rb)?
    | 205 => TwoPCPhase2Msg.decode(consume rb)?
    | 206 => WorkersLeftMsg.decode(consume rb)?
    else
      error
    end

  fun apply(msg: TwoPCMessage): U8 =>
    match msg
    | let m: ListUncommittedMsg => 201
    | let m: ReplyUncommittedMsg => 202
    | let m: TwoPCPhase1Msg => 203
    | let m: TwoPCReplyMsg => 204
    | let m: TwoPCPhase2Msg => 205
    | let m: WorkersLeftMsg => 206
    end

class ListUncommittedMsg is MessageTrait
  let rtag: U64

  new create(rtag': U64) =>
    rtag = rtag'

  new decode(rb: Reader)? =>
    let rtag' = rb.u64_be()?
    rtag = rtag'

  fun encode(wb: Writer = Writer): Writer =>
    wb.u64_be(rtag)
    wb

class ReplyUncommittedMsg is MessageTrait
  let rtag: U64
  let txn_ids: Array[String] val

  new create(rtag': U64, txn_ids': Array[String val] val) =>
    rtag = rtag'
    txn_ids = txn_ids'

  new decode(rb: Reader)? =>
    let rtag' = rb.u64_be()?
    let a_len = rb.u32_be()?
    let txn_ids' = recover trn Array[String] end
    for i in col.Range[U32](0, a_len) do
      let length = rb.u16_be()?.usize()
      txn_ids'.push(String.from_array(rb.block(length)?))
    end
    rtag = rtag'
    txn_ids = consume txn_ids'

  fun encode(wb: Writer = Writer): Writer =>
    wb.u64_be(rtag)
    wb.u32_be(txn_ids.size().u32())
    for txn_id in txn_ids.values() do
      wb.u16_be(txn_id.size().u16())
      wb.write(txn_id)
    end
    wb

class WorkersLeftMsg is MessageTrait
  let rtag: U64
  let leaving_workers: Array[WorkerName val] val

  new create(rtag': U64, leaving_workers': Array[WorkerName val] val) =>
    rtag = rtag'
    leaving_workers = leaving_workers'

  new decode(rb: Reader)? =>
    let rtag' = rb.u64_be()?
    let a_len = rb.u32_be()?
    let leaving_workers' = recover trn Array[String] end
    for i in col.Range[U32](0, a_len) do
      let length = rb.u16_be()?.usize()
      leaving_workers'.push(String.from_array(rb.block(length)?))
    end
    rtag = rtag'
    leaving_workers = consume leaving_workers'

  fun encode(wb: Writer = Writer): Writer =>
    wb.u64_be(rtag)
    wb.u32_be(leaving_workers.size().u32())
    for w in leaving_workers.values() do
      wb.u16_be(w.size().u16())
      wb.write(w)
    end
    wb


type WhereList is Array[(U64, U64, U64)]

class TwoPCPhase1Msg is MessageTrait
  var txn_id: String = ""
  var where_list: WhereList

  new create(txn_id': String, where_list': WhereList) =>
    txn_id = txn_id'
    where_list = where_list'

  new decode(rb: Reader)? =>
    var length = rb.u16_be()?.usize()
    let txn_id' = String.from_array(rb.block(length)?)
    let where_list' = recover trn WhereList end
    length = rb.u32_be()?.usize()
    for i in col.Range[USize](0, length) do
      let stream_id = rb.u64_be()?
      let start_por = rb.u64_be()?
      let end_por = rb.u64_be()?
      where_list'.push((stream_id, start_por, end_por))
    end
    txn_id = txn_id'
    where_list = consume where_list'

  fun encode(wb: Writer = Writer): Writer =>
    wb.u16_be(txn_id.size().u16())
    wb.write(txn_id)
    wb.u32_be(where_list.size().u32())
    for (stream_id, start_por, end_por) in where_list.values() do
      wb.u64_be(stream_id)
      wb.u64_be(start_por)
      wb.u64_be(end_por)
    end
    wb

class TwoPCReplyMsg is MessageTrait
  var txn_id: String = ""
  var commit: Bool = false

  new create(txn_id': String, commit': Bool) =>
    txn_id = txn_id'
    commit = commit'

  new decode(rb: Reader)? =>
    (let txn_id', let commit') = _P.decode_phase2r(rb)?
    txn_id = txn_id'
    commit = commit'

  fun encode(wb: Writer = Writer): Writer =>
    _P.encode_phase2r(txn_id, commit, wb)

class TwoPCPhase2Msg is MessageTrait
  var txn_id: String = ""
  var commit: Bool = false

  new create(txn_id': String, commit': Bool) =>
    txn_id = txn_id'
    commit = commit'

  new decode(rb: Reader)? =>
    (let txn_id', let commit') = _P.decode_phase2r(rb)?
    txn_id = txn_id'
    commit = commit'

  fun encode(wb: Writer = Writer): Writer =>
    _P.encode_phase2r(txn_id, commit, wb)

primitive _P
  fun decode_phase2r(rb: Reader): (String, Bool)?
  =>
    let length = rb.u16_be()?.usize()
    let txn_id' = String.from_array(rb.block(length)?)
    let commit' = if rb.u8()? == 0 then false else true end
    (txn_id', commit')

  fun encode_phase2r(txn_id: String, commit: Bool, wb: Writer): Writer
  =>
    wb.u16_be(txn_id.size().u16())
    wb.write(txn_id)
    if commit then wb.u8(1) else wb.u8(0) end
    wb
