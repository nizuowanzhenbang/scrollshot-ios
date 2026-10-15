import argparse, hashlib, json, pathlib, plistlib, struct, zipfile

def executable(data):
    if data[:4] != b'\xcf\xfa\xed\xfe' or struct.unpack_from('<I',data,4)[0] != 0x100000c:
        raise ValueError('Executable must be thin ARM64 Mach-O')
    commands=struct.unpack_from('<I',data,16)[0]; offset=32; entitlements={}; minimum=None; platform=None
    for _ in range(commands):
        cmd,size=struct.unpack_from('<II',data,offset)
        if size < 8 or offset+size > len(data): raise ValueError('Invalid load command')
        if cmd==0x32: platform,minimum=struct.unpack_from('<II',data,offset+8)
        if cmd in (0x21,0x2c) and struct.unpack_from('<I',data,offset+16)[0] != 0: raise ValueError('Encrypted executable')
        if cmd==0x1d:
            sig,length=struct.unpack_from('<II',data,offset+8)
            magic,total,count=struct.unpack_from('>III',data,sig)
            if magic!=0xfade0cc0: raise ValueError('Invalid signature superblob')
            for i in range(count):
                typ,relative=struct.unpack_from('>II',data,sig+12+8*i)
                blob,sz=struct.unpack_from('>II',data,sig+relative)
                if blob==0xfade7171: entitlements=plistlib.loads(data[sig+relative+8:sig+relative+sz])
        offset+=size
    if minimum != (18<<16) or platform != 2: raise ValueError('Expected device iOS 18.0 deployment command')
    return entitlements

def verify(path,mode):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None: raise ValueError('ZIP CRC mismatch')
        names=archive.namelist()
        apps=[n for n in names if n.startswith('Payload/') and n.endswith('.app/Info.plist') and n.count('/')==2]
        if len(apps)!=1: raise ValueError('Expected exactly one main app')
        info=plistlib.loads(archive.read(apps[0])); root=apps[0][:-len('Info.plist')]
        if info.get('CFBundleSupportedPlatforms')!=['iPhoneOS']: raise ValueError('Not a device app')
        main=executable(archive.read(root+info['CFBundleExecutable']))
        plugins=[n for n in names if n.startswith(root+'PlugIns/') and n.endswith('.appex/Info.plist')]
        group=info.get('AppGroupIdentifier')
        if mode=='standard':
            if len(plugins)!=1: raise ValueError('Standard build must contain broadcast extension')
            ext=plistlib.loads(archive.read(plugins[0])); extroot=plugins[0][:-len('Info.plist')]
            ex=executable(archive.read(extroot+ext['CFBundleExecutable']))
            if not ext['CFBundleIdentifier'].startswith(info['CFBundleIdentifier']+'.'): raise ValueError('Extension bundle ID mismatch')
            if ext.get('NSExtension',{}).get('NSExtensionPointIdentifier')!='com.apple.broadcast-services-upload': raise ValueError('Wrong extension point')
            if not group or main.get('com.apple.security.application-groups')!=[group] or ex.get('com.apple.security.application-groups')!=[group] or ext.get('AppGroupIdentifier')!=group: raise ValueError('App Group mismatch')
        elif plugins or group or main.get('com.apple.security.application-groups'):
            raise ValueError('Import build must have no extension or App Groups')
        if any(n.endswith(('.p12','.mobileprovision')) for n in names): raise ValueError('Unexpected signing material')
        return {'file':pathlib.Path(path).name,'mode':mode,'bundle_id':info['CFBundleIdentifier'],'version':info['CFBundleShortVersionString'],'arm64':True,'minimum_ios':'18.0','extensions':len(plugins),'app_group':group,'zip_crc':'PASS','sha256':hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest(),'signing':'ad-hoc; must be re-signed for physical device'}

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('ipa'); parser.add_argument('--mode',required=True,choices=['standard','import'])
    args=parser.parse_args(); print(json.dumps(verify(args.ipa,args.mode),ensure_ascii=False,indent=2))
