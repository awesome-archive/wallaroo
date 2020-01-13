# Copyright 2019 The Wallaroo Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.


import argparse
from json import loads
import struct


parser = argparse.ArgumentParser("Multi Pipeline Validator")
parser.add_argument("--output", type=argparse.FileType("rb"),
                    help="The output file of the application.")
parser.add_argument("--expected", type=argparse.FileType("rb"),
                    help="The expected file for validation.")
args = parser.parse_args()

expected = loads(args.expected.read())
keys = expected.keys()
for k in keys:
    kk = int(k)
    expected[kk] = expected.pop(k)

f = args.output
received = {}
while True:
    header_bytes = f.read(4)
    if not header_bytes:
        break
    header = struct.unpack('>I', header_bytes)[0]
    payload = f.read(header)
    assert(len(payload) > 0)
    key, val = struct.unpack('>II', payload)
    received.setdefault(key, []).append(val)

for key in (1,2):
    for x in range(0, 1000):
        err = "key: {}, position: {}, expected: {}, received: {}".format(
            key, x, expected[key][x], received[key][x])
        assert(expected[key][x] == received[key][x]), err
        #assert(1 == 2), err
