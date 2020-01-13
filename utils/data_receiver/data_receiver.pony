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

use "net"
use "wallaroo_labs/bytes"
use "wallaroo_labs/mort"
use "wallaroo_labs/options"

actor Main
  new create(env: Env) =>
    var required_args_are_present = true
    var l_arg: (Array[String] | None) = None
    var output_mode: OutputMode = Write
    var input_mode: InputMode = Streaming
    var buffer_size: USize = 16384

    try
      var options = Options(env.args)

      options.add("framed", "f", None)
      options.add("help", "h", None)
      options.add("listen", "l", StringArgument)
      options.add("no-write", "n", None)
      options.add("buffer-size", "b", I64Argument)

      for option in options do
        match option
        | ("help", None) => usage(env.out); return
        | ("listen", let arg: String) => l_arg = arg.split(":")
        | ("no-write", None) => output_mode = NoWrite
        | ("framed", None) => input_mode = Framed
        | ("buffer-size", let arg: I64) => arg.usize()
        | let err: ParseError =>
          err.report(env.err)
          usage(env.out)
        end
      end

      if l_arg is None then
        env.err.print("Must supply required '--listen' argument")
        required_args_are_present = false
      else
        if (l_arg as Array[String]).size() != 2 then
          env.err.print(
            "'--listen' argument should be in format: '127.0.0.1:7669")
          required_args_are_present = false
        end
      end

      if not required_args_are_present then
        error
      end

      // Start it up!
      let listener_addr = l_arg as Array[String]
      let host = listener_addr(0)?
      let port = listener_addr(1)?
      let tcp_auth = TCPListenAuth(env.root as AmbientAuth)
      TCPListener(tcp_auth,
        ListenerNotify(env.out, env.err, input_mode, output_mode, host, port),
        host, port where read_buffer_size = buffer_size)
    else
      usage(env.out)
    end

  fun usage(out: OutStream) =>
    out.print(
      "data_receiver [OPTIONS]\n" +
      "Required: \n" +
      "  --listen   ADDRESS:PORT  e.g. 127.0.0.1:7669\n" +
      "    Address and port to listen for data on.\n" +
      "Optional: \n" +
      "  --no-write\n" +
      "    Don't write received data to STDOUT\n" +
      "  --framed\n" +
      "    Read a framed message protocol with 4 byte header\n" +
      "  --buffer-size\n" +
      "    Set the max buffer size for the TCP connection in bytes\n"
      )

class ListenerNotify is TCPListenNotify
  let _stdout: OutStream
  let _stderr: OutStream
  let _input_mode: InputMode
  let _output_mode: OutputMode
  let _host: String
  let _port: String

  new iso create(stdout: OutStream,
    stderr: OutStream,
    input_mode: InputMode,
    output_mode: OutputMode,
    host: String,
    port: String)
  =>
    _stdout = stdout
    _stderr = stderr
    _input_mode = input_mode
    _output_mode = output_mode
    _host = host
    _port = port

  fun ref listening(listen: TCPListener ref) =>
    _stdout.print("Listening on " + _host + ":" + _port)

  fun ref not_listening(listen: TCPListener ref) =>
    _stderr.print("Unable to listen\n")

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    ConnectionNotify(_stdout, _stderr, _input_mode, _output_mode)

class ConnectionNotify is TCPConnectionNotify
  let _stdout: OutStream
  let _stderr: OutStream
  let _input_mode: InputMode
  let _output_mode: OutputMode
  var _read_header: Bool = true

  new iso create(so: OutStream, se: OutStream, i: InputMode, o: OutputMode) =>
    _stdout = so
    _stderr = se
    _input_mode = i
    _output_mode = o

  fun ref received(c: TCPConnection ref, d: Array[U8] iso, n: USize): Bool =>
    match _input_mode
    | Framed =>
      if _read_header then
        try
          let expect = Bytes.to_u32(d(0)?, d(1)?, d(2)?, d(3)?).usize()
          try
            c.expect(expect)?
          else
            _stderr.print("Received an expect larger than 16kb. Exiting.")
            c.close()
          end
          _read_header = false
        else
          _stderr.print("Bad framed header value. Exiting.")
          c.close()
        end
      else
        match _output_mode
        | Write =>
          _stdout.print(consume d)
        end
        try
          c.expect(4)?
        else
          Fail()
        end
        _read_header = true
      end
    | Streaming =>
      match _output_mode
      | Write => _stdout.write(consume d)
      end
    end

    true

  fun ref accepted(c: TCPConnection ref) =>
    match _input_mode
    | Framed =>
      try
        c.expect(4)?
      else
        Fail()
      end
    end

  fun ref connect_failed(c: TCPConnection ref) =>
    // We don't initiate outgoing connections so this can never happen
    None

primitive Write
primitive NoWrite

type OutputMode is (Write | NoWrite)

primitive Streaming
primitive Framed

type InputMode is (Streaming | Framed)
