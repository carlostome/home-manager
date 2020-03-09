# A partial and basic implementation of GVariant formatted strings.
#
# Note, this API is not considered fully stable and it might therefore
# change in backwards incompatible ways without prior notice.

{ lib }:

with lib;

let

  primitiveOf = t: v: {
    _type = "gvariant";
    type = t;
    value = v;
    __toString = self: "@${self.type} ${toString self.value}";
  };

  type = {
    array = t: "a${t}";
    tuple = ts: "(${concatStrings ts})";
    string = "s";
    boolean = "b";
    uchar = "y";
    int16 = "n";
    uint16 = "q";
    int32 = "i";
    uint32 = "u";
    int64 = "x";
    uint64 = "t";
    double = "d";
  };

  # Returns the GVariant type of a given Nix value. If no type can be
  # found for the value then the empty string is returned.
  typeOf = v:
    with type;
    if builtins.isBool v then
      boolean
    else if builtins.isInt v then
      int32
    else if builtins.isFloat v then
      double
    else if builtins.isString v then
      string
    else if builtins.isList v then
      let elemType = elemTypeOf v;
      in if elemType == "" then "" else array elemType
    else if builtins.isAttrs v && v ? type then
      v.type
    else
      "";

  elemTypeOf = vs:
    if builtins.isList vs then if vs == [ ] then "" else typeOf (head vs) else "";

in rec {

  inherit type typeOf;

  isArray = hasPrefix "a";
  isTuple = hasPrefix "(";

  # Returns the GVariant value that most closely matches the given Nix
  # value. If no GVariant value can be found then `null` is returned.
  #
  # No support for dictionaries, maybe types, or variants.
  valueOf = v:
    if builtins.isBool v then
      booleanOf v
    else if builtins.isInt v then
      int32Of v
    else if builtins.isFloat v then
      doubleOf v
    else if builtins.isString v then
      stringOf v
    else if builtins.isList v then
      if v == [ ] then arrayOf type.string [ ] else arrayOf (elemTypeOf v) v
    else if builtins.isAttrs v && (v._type or "") == "gvariant" then
      v
    else
      null;

  arrayOf = elemType: elems:
    primitiveOf (type.array elemType) (map valueOf elems) // {
      __toString = self:
        "@${self.type} [${concatMapStringsSep "," toString self.value}]";
    };

  emptyArrayOf = elemType: arrayOf elemType [ ];

  tupleOf = elems:
    let
      gvarElems = map valueOf elems;
      tupleType = type.tuple (map (e: e.type) gvarElems);
    in primitiveOf tupleType gvarElems // {
      __toString = self:
        "@${self.type} (${concatMapStringsSep "," toString self.value})";
    };

  booleanOf = v:
    primitiveOf type.boolean v // {
      __toString = self: if self.value then "true" else "false";
    };

  stringOf = v:
    primitiveOf type.string v // {
      __toString = self: "'${escape [ "'" ] self.value}'";
    };

  objectpathOf = v:
    primitiveOf type.string v // {
      __toString = self: "objectpath '${escape [ "'" ] self.value}'";
    };

  ucharOf = primitiveOf type.uchar;

  int16Of = primitiveOf type.int16;

  uint16Of = primitiveOf type.uint16;

  int32Of = v:
    primitiveOf type.int32 v // {
      __toString = self: toString self.value;
    };

  uint32Of = primitiveOf type.uint32;

  int64Of = primitiveOf type.int64;

  uint64Of = primitiveOf type.uint64;

  doubleOf = v:
    primitiveOf type.double v // {
      __toString = self: toString self.value;
    };

}
