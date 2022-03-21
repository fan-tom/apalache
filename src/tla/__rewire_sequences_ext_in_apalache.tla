------------------------ MODULE SequencesExt ---------------------------------
\*------ MODULE __rewire_sequences_ext_in_apalache -----------------------
(**
 * ^^^^^^^^^^^^^^^^^^^^^^ We have to call this module SequencesExt in any
 * case, otherwise, SANY complains.
 *
 * This file contains alternative definitions for the operators defined in
 * SequencesExt. Most importantly, we are adding type annotations. We also
 * define the Apalache-compatible behavior.
 *
 * These definitions are automatically rewired by the Apalache importer.
 *
 * Compare with the original definitions in SequencesExt.tla:
 *
 * https://github.com/tlaplus/CommunityModules/blob/master/modules/SequencesExt.tla
 *)

LOCAL INSTANCE Integers
LOCAL INSTANCE Sequences
LOCAL INSTANCE FiniteSets
LOCAL INSTANCE __apalache_folds
LOCAL INSTANCE __apalache_internal

(**
 * The image of the given sequence s. Cardinality(ToSet(s)) <= Len(s)
 * see https://en.wikipedia.org/wiki/Image_(mathematics)
 *
 * @type: Seq(a) => Set(a);
 *)
ToSet(s) ==
  { s[i] : i \in DOMAIN s }

(**
 * Convert a set to some sequence that contains all the elements of the
 * set exactly once, and contains no other elements.
 *
 * @type: Set(a) => Seq(a);
 *)
SetToSeq(S) == 
  LET __add_to_seq(seq, elem) == Append(seq, elem) IN
  __ApalacheFoldSet(__add_to_seq, <<>>, S)

(**
 * Convert a set to a sorted sequence that contains all the elements of
 * the set exactly once, and contains no other elements.
 *
 * @type: (Set(a), (a, a) => Bool) => Seq(a);
 *)
SetToSortSeq(S, LessThan(_, _)) ==
  \* insert a new element element 
  LET \* @type: (Seq(b), b) => Seq(b);
        __insert_sorted(seq, newElem) ==
    \* find the position for inserting the element at
    LET __insertion_pos ==
      CHOOSE p \in (DOMAIN seq) \union { Len(seq) + 1 }:
        \A i \in DOMAIN seq:
          i < p <=> LessThan(seq[i], newElem)
    IN
    \* copy the sequence elements or insert a new one
    LET __copy_or_set(i) ==
      IF i < __insertion_pos
      THEN seq[i]
      ELSE IF i = __insertion_pos
           THEN newElem
           ELSE seq[i + 1]
    IN
    __ApalacheMkSeq(__ApalacheSeqCapacity(seq) + 1, __copy_or_set)
  IN
  __ApalacheFoldSet(__insert_sorted, <<>>, S)

(**
 * TupleOf(s, 3) = s \X s \X s
 *
 * This operator is not well-typed.
 * Hence, we assign a reasonable type signature.
 *
 * @type: (Set(a), Int) => (Int -> Set(a));
 *)
TupleOf(set, n) == 
  __NotSupportedByModelChecker("TupleOf")

(**
 * All sequences up to length n with all elements in set.  Includes empty
 * sequence.
 *
 * Apalache does not support this operator. Try Apalache!Gen instead.
 *
 * @type: (Set(a), Int) => Set(Seq(a));
 *)
SeqOf(set, n) == 
  __NotSupportedByModelChecker("SeqOf")

(**
 * An alias for SeqOf to make the connection to Sequences!Seq, which is
 * the unbounded version of BoundedSeq.
 *
 * Apalache does not support this operator. Try Apalache!Gen instead.
 *
 * @type: (Set(a), Int) => Set(Seq(a));
 *)
BoundedSeq(S, n) ==
  __NotSupportedByModelChecker("SeqOf")

(**
 * TRUE iff the element e \in ToSet(s).
 *
 * @type: (Seq(a), a) => Bool;
 *)
Contains(s, e) ==
  \E i \in DOMAIN s:
    s[i] = e

(**
 * Reverse the given sequence s:  Let l be Len(s) (length of s).
 * Equals a sequence s.t. << s[l], s[l - 1], ..., s[1]>>.
 *
 * @type: Seq(a) => Seq(a);
 *)
Reverse(s) ==
  LET __s_len == Len(s) IN
  LET __get_ith(i) == s[__s_len - i + 1] IN
  SubSeq(__ApalacheMkSeq(__ApalacheSeqCapacity(s), __get_ith), 1, __s_len)

(**
 * The sequence s with e removed or s iff e \notin Range(s).
 *
 * @type: (Seq(a), a) => Seq(a);
 *)
Remove(seq, e) ==
    LET __append_if_eq(res, t) ==
        IF t /= e
        THEN Append(res, e)
        ELSE res
    IN
    __ApalacheFoldSeq(__append_if_eq, <<>>, seq)

(**
 * Equals the sequence s except that all occurrences of element old are
 * replaced with the element new.
 *
 * @type: (Seq(a), a, a) => Seq(a);
 *)
ReplaceAll(seq, old, new) ==
  LET __copy_or_set(i) ==
    IF seq[i] = old THEN new ELSE seq[i]
  IN
  SubSeq(__ApalacheMkSeq(__ApalacheSeqCapacity(seq), __copy_or_set),
        1, Len(seq))
  
(**  
 * Inserts element e at the position i moving the original element to i+1
 * and so on.  In other words, a sequence t s.t.:
 *   /\ Len(t) = Len(s) + 1
 *   /\ t[i] = e
 *   /\ \A j \in 1..(i - 1): t[j] = s[j]
 *   /\ \A k \in (i + 1)..Len(s): t[k + 1] = s[k]
 *
 * @type: (Seq(a), Int, a) => Seq(a);
 *)
InsertAt(seq, k, e) ==
  LET __copy_or_set(i) ==
    IF i = e
    THEN e
    ELSE IF i < k
         THEN seq[i]
         ELSE seq[i - 1]
  IN
  SubSeq(__ApalacheMkSeq(__ApalacheSeqCapacity(seq) + 1, __copy_or_set),
        1, Len(seq) + 1)

(**
 * Replaces the element at position i with the element e.
 *
 * @type: (Seq(a), Int, a) => Seq(a);
 *)
ReplaceAt(s, i, e) ==
  [s EXCEPT ![i] = e]  

(**
 * Replaces the element at position i shortening the length of s by one.
 *
 * @type: (Seq(a), Int) => Seq(a);
 *)
RemoveAt(s, i) == 
  SubSeq(s, 1, i - 1) \o SubSeq(s, i + 1, Len(s))

-----------------------------------------------------------------------------

(**
 * Cons prepends an element at the beginning of a sequence.
 *
 * @type: (a, Seq(a)) => Seq(a);
 *)
Cons(elt, seq) == 
    <<elt>> \o seq

(**
 * The sequence formed by removing its last element.
 *
 * @type: Seq(a) => Seq(a);
 *)
Front(seq) == 
  SubSeq(seq, 1, Len(seq) - 1)

(**
 * The last element of the sequence.
 *
 * @type: Seq(a) => a;
 *)
Last(seq) ==
  seq[Len(seq)]

-----------------------------------------------------------------------------

(**
 * TRUE iff the sequence s is a prefix of the sequence t, s.t.
 * \E u \in Seq(Range(t)) : t = s \o u. In other words, there exists
 * a suffix u that with s prepended equals t.
 *
 * @type: (Seq(a), Seq(a)) => Bool;
 *)
IsPrefix(s, t) ==
  Len(s) <= Len(t) /\ SubSeq(s, 1, Len(s)) = SubSeq(t, 1, Len(s))

(**
 * TRUE iff the sequence s is a prefix of the sequence t and s # t
 *
 * @type: (Seq(a), Seq(a)) => Bool;
 *)
IsStrictPrefix(s,t) ==
  IsPrefix(s, t) /\ s # t

(**
 * TRUE iff the sequence s is a suffix of the sequence t, s.t.
 * \E u \in Seq(Range(t)) : t = u \o s. In other words, there exists a
 * prefix that with s appended equals t.
 *
 * @type: (Seq(a), Seq(a)) => Bool;
 *)
IsSuffix(s, t) ==
  IsPrefix(Reverse(s), Reverse(t))

(**
 * TRUE iff the sequence s is a suffix of the sequence t and s # t
 *
 * @type: (Seq(a), Seq(a)) => Bool;
 *)
IsStrictSuffix(s, t) ==
  IsSuffix(s,t) /\ s # t
  
-----------------------------------------------------------------------------

(**
 * The set of prefixes of the sequence s, including the empty sequence.
 *
 * @type: Seq(a) => Set(Seq(a));
 *)
Prefixes(s) ==
  { SubSeq(s, 1, l) : l \in DOMAIN s } \union { <<>> }

(**
 * The set of all sequences that are prefixes of the set of sequences S.
 *
 * @type: Set(Seq(a)) => Set(Seq(a));
 *)
CommonPrefixes(S) ==
  \* TODO: use FoldSet?
  LET P == UNION { Prefixes(seq) : seq \in S }
  IN { prefix \in P : \A t \in S: IsPrefix(prefix, t) }

(**
 * The longest common prefix of the sequences in the set S.
 *
 * @type: Set(Seq(a)) => Seq(a);
 *)
LongestCommonPrefix(S) ==
  CHOOSE longest \in CommonPrefixes(S):  \* there can only be one LCP => CHOOSE
      \A other \in CommonPrefixes(S):
          Len(other) <= Len(longest)

-----------------------------------------------------------------------------

(**
 * Range(a % b) = 0..b-1, but DOMAIN seq = 1..Len(seq).
 * So to do modular arithmetic on sequences we need to map 0 to b.
 *
 * @type: (Int, Int) => Int;
 *)
SeqMod(a, b) == 
  IF a % b = 0 THEN b ELSE a % b

(**
 * An alias of FoldFunction that op on all elements of seq an arbitrary
 * order. The resulting function is:
 *
 *    op(f[i],op(f[j], ..., op(f[k],base) ...))
 *
 * op must be associative and commutative, because we can not assume a
 * particular ordering of i, j, and k
 *
 * Example:
 *
 *  FoldSeq(LAMBDA x,y: {x} \cup y, {}, <<1,2,1>>) = Range(<<1,2,1>>)
 *
 * @type: ((a, b) => b, b, Seq(a)) => b;
 *)
FoldSeq(op(_, _), base, seq) == 
  \* __ApalacheFoldSeq is accumulating the result in the left argument,
  \* whereas FoldSeq is accumulating the result in the right argument.
  LET __map(y, x) == op(x, y) IN
  __ApalacheFoldSeq(__map, base, seq)

(**
 * FoldLeft folds op on all elements of seq from left to right, starting
 * with the first element and base. The resulting function is:
 *    op(op(...op(base,f[0]), ...f[n-1]), f[n])
 *
 * Example:
 *    LET cons(x,y) == <<x,y>>
 *    IN FoldLeft(cons, 0, <<3,1,2>>) = << << <<0,3>>, 1>>, 2>> 
 *
 * @type: ((a, b) => a, a, Seq(a)) => a;
 *)
FoldLeft(op(_, _), base, seq) == 
  __ApalacheFoldSeq(op, base, seq)

(**
 * FoldRight folds op on all elements of seq from right to left, starting
 * with the last element and base. The resulting function is:
 *    op(f[0],op(f[1], ..., op(f[n],base) ...))
 *
 *
 * Example:
 *    LET cons(x,y) == <<x,y>>
 *    IN FoldRight(cons, <<3,1,2>>, 0 ) = << 3, << 1, <<2,0>> >> >> 
 *
 * @type: ((a, b) => b, b, Seq(a)) => b;
 *)
FoldRight(op(_, _), seq, base) == 
  LET __map(y, x) == op(x, y) IN
  __ApalacheFoldSeq(__map, base, Reverse(seq))

===============================================================================
