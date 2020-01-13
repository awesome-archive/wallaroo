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

use "random"
use "time"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"


// The user defines a KeyExtractor for partitioning by key
interface val KeyExtractor[In: Any val]
  fun apply(input: In): Key

class val CollectKeyExtractor[In: Any val]
  let _constant_key: Key

  new val create(c_key: Key) =>
    _constant_key = c_key

  fun apply(input: In): Key =>
    _constant_key

trait Partitioner
  // Takes an input and the current key associated with that input.
  // Based on a new partitioning scheme, it might replace this old key with
  // a new one.
  fun ref apply[D: Any val](d: D, current_key: Key): Key

trait val PartitionerBuilder
  fun apply(): Partitioner

primitive PassthroughPartitionerBuilder is PartitionerBuilder
  fun apply(): PassthroughPartitioner =>
    PassthroughPartitioner

class PassthroughPartitioner is Partitioner
  fun ref apply[D: Any val](d: D, current_key: Key): Key =>
    current_key

primitive SinglePartitionerBuilder is PartitionerBuilder
  fun apply(): SinglePartitioner =>
    SinglePartitioner

class SinglePartitioner is Partitioner
  fun ref apply[D: Any val](d: D, current_key: Key): Key =>
    "single-partition-key"

primitive RandomPartitionerBuilder is PartitionerBuilder
  fun apply(): RandomPartitioner =>
    RandomPartitioner

class RandomPartitioner is Partitioner
  let _rand: Random

  new create(seed: U64 = Time.nanos()) =>
    _rand = MT(seed)

  fun ref apply[D: Any val](d: D, current_key: Key): Key =>
    _rand.next().string()

trait val KeyPartitionerBuilder is PartitionerBuilder
  fun apply(): KeyPartitioner

class val TypedKeyPartitionerBuilder[In: Any val] is KeyPartitionerBuilder
  let key_extractor: KeyExtractor[In]

  new val create(ke: KeyExtractor[In]) =>
    key_extractor = ke

  fun apply(): KeyPartitioner =>
    TypedKeyPartitioner[In](key_extractor)

trait KeyPartitioner is Partitioner
  fun ref apply[D: Any val](d: D, current_key: Key): Key

class TypedKeyPartitioner[In: Any val] is KeyPartitioner
  let key_extractor: KeyExtractor[In]

  new create(ke: KeyExtractor[In]) =>
    key_extractor = ke

  fun ref apply[D: Any val](d: D, current_key: Key): Key =>
    match d
    | let i: In =>
      key_extractor(i)
    else
      Fail()
      ""
    end
