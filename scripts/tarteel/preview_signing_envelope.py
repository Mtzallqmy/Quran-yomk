"""Reproduce a locally signed preview from an exact Actions build, without keys.

An envelope contains only public ZIP headers, certificate/signature blocks and
references into unchanged APK entry bytes. It cannot sign a different build:
both the complete unsigned and signed APK SHA-256 values must match. Android's
apksigner verification remains a separate mandatory release gate.
"""
import argparse
import base64
import hashlib
import json
import struct
import zipfile
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def data_offset(data, info):
    assert data[info.header_offset:info.header_offset+4] == b'PK\x03\x04'
    name, extra = struct.unpack_from('<HH', data, info.header_offset+26)
    return info.header_offset+30+name+extra


def create(unsigned, signed):
    before, after = unsigned.read_bytes(), signed.read_bytes()
    with zipfile.ZipFile(unsigned) as a, zipfile.ZipFile(signed) as b:
        old = {x.filename:x for x in a.infolist()}
        ops, cursor = [], 0
        for info in sorted(b.infolist(), key=lambda x:x.header_offset):
            start = data_offset(after, info)
            end = start+info.compress_size
            previous = old.get(info.filename)
            if previous is None:
                continue
            source = data_offset(before, previous)
            if before[source:source+previous.compress_size] != after[start:end]:
                continue
            if start > cursor:
                ops.append(base64.b64encode(after[cursor:start]).decode())
            ops.append([source, info.compress_size])
            cursor = end
        if cursor < len(after):
            ops.append(base64.b64encode(after[cursor:]).decode())
    envelope = dict(format=1,unsigned_sha256=sha(before),signed_sha256=sha(after),
                    signed_bytes=len(after),operations=ops)
    assert reconstruct(before,envelope) == after
    return envelope


def reconstruct(before, envelope):
    if envelope['format'] != 1 or sha(before) != envelope['unsigned_sha256']:
        raise ValueError('Envelope belongs to another unsigned build')
    size = envelope['signed_bytes']
    if type(size) is not int or size < 1 or size > 100*1024*1024:
        raise ValueError('Invalid APK size')
    result = bytearray()
    ops = envelope['operations']
    if not isinstance(ops,list) or len(ops)>20000:
        raise ValueError('Invalid operation count')
    literal_bytes = 0
    for op in ops:
        if isinstance(op,str):
            literal = base64.b64decode(op,validate=True)
            literal_bytes += len(literal)
            if literal_bytes > 2*1024*1024:
                raise ValueError('Envelope contains too much literal data')
            result.extend(literal)
        elif isinstance(op,list) and len(op)==2 and all(type(v) is int for v in op):
            start,length = op
            if start<0 or length<0 or start+length>len(before):
                raise ValueError('Invalid copy range')
            result.extend(before[start:start+length])
        else:
            raise ValueError('Invalid envelope operation')
        if len(result)>size:
            raise ValueError('APK exceeds declared size')
    if len(result)!=size or sha(result)!=envelope['signed_sha256']:
        raise ValueError('Signed APK digest mismatch')
    return bytes(result)


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('mode',choices=['create','apply'])
    parser.add_argument('--unsigned',type=Path,required=True)
    parser.add_argument('--signed',type=Path)
    parser.add_argument('--envelope',type=Path,required=True)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.mode=='create':
        result=create(args.unsigned,args.signed)
        args.envelope.write_text(json.dumps(result,separators=(',',':'))+'\n')
        print('Public envelope written; no signing key is included.')
    else:
        args.output.write_bytes(reconstruct(args.unsigned.read_bytes(),json.loads(args.envelope.read_text())))
        print('Exact externally signed APK reconstructed; verify with apksigner before publishing.')
