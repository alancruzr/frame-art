/** Decodificador CBOR mínimo (RFC 8949) para objetos de App Attest: enteros, bytes, texto, arrays y mapas. */
export type CborValue = number | bigint | string | Uint8Array | CborValue[] | Map<CborValue, CborValue> | boolean | null | undefined;

export function decodeCbor(input: Uint8Array): CborValue {
  const view = new DataView(input.buffer, input.byteOffset, input.byteLength);
  let pos = 0;

  const readLength = (info: number): number => {
    if (info < 24) return info;
    if (info === 24) return view.getUint8(pos++);
    if (info === 25) { const v = view.getUint16(pos); pos += 2; return v; }
    if (info === 26) { const v = view.getUint32(pos); pos += 4; return v; }
    if (info === 27) {
      const v = view.getBigUint64(pos); pos += 8;
      if (v > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("cbor: length too large");
      return Number(v);
    }
    throw new Error("cbor: indefinite lengths not supported");
  };

  const item = (): CborValue => {
    if (pos >= input.length) throw new Error("cbor: unexpected end");
    const initial = view.getUint8(pos++);
    const major = initial >> 5;
    const info = initial & 0x1f;
    switch (major) {
      case 0: return readLength(info);
      case 1: return -1 - readLength(info);
      case 2: {
        const len = readLength(info);
        if (pos + len > input.length) throw new Error("cbor: bytes out of range");
        const out = input.slice(pos, pos + len); pos += len; return out;
      }
      case 3: {
        const len = readLength(info);
        if (pos + len > input.length) throw new Error("cbor: text out of range");
        const out = new TextDecoder().decode(input.subarray(pos, pos + len)); pos += len; return out;
      }
      case 4: {
        const len = readLength(info);
        const arr: CborValue[] = [];
        for (let i = 0; i < len; i++) arr.push(item());
        return arr;
      }
      case 5: {
        const len = readLength(info);
        const map = new Map<CborValue, CborValue>();
        for (let i = 0; i < len; i++) { const k = item(); map.set(k, item()); }
        return map;
      }
      case 6: readLength(info); return item(); // tag: ignorar
      case 7:
        if (info === 20) return false;
        if (info === 21) return true;
        if (info === 22) return null;
        if (info === 23) return undefined;
        throw new Error("cbor: unsupported simple/float");
      default:
        throw new Error("cbor: bad major type");
    }
  };

  const value = item();
  return value;
}

export function mapGet(map: CborValue, key: string): CborValue {
  if (!(map instanceof Map)) throw new Error("cbor: expected map");
  return map.get(key);
}
