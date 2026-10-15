import pathlib,tempfile,unittest,zipfile,plistlib,struct
from verify_ipa import verify

def macho(groups=None,minimum=18<<16,platform=2):
    ent=plistlib.dumps({'com.apple.security.application-groups':groups} if groups else {})
    blob=struct.pack('>II',0xfade7171,8+len(ent))+ent
    signature=struct.pack('>5I',0xfade0cc0,20+len(blob),1,5,20)+blob
    header=struct.pack('<8I',0xfeedfacf,0x100000c,0,2,2,40,0,0)
    build=struct.pack('<6I',0x32,24,platform,minimum,18<<16,0)
    codesig=struct.pack('<4I',0x1d,16,72,len(signature))
    return header+build+codesig+signature

class PackageChecks(unittest.TestCase):
    def package(self,mode='import',missing=False,groups=None,minimum=18<<16,platform=2):
        directory=tempfile.TemporaryDirectory(); self.addCleanup(directory.cleanup)
        path=pathlib.Path(directory.name)/'test.ipa'
        root='Payload/Test.app/'
        info={'CFBundleIdentifier':'com.example.test','CFBundleExecutable':'Test','CFBundleShortVersionString':'0.1.0','CFBundleSupportedPlatforms':['iPhoneOS']}
        if mode=='standard': info['AppGroupIdentifier']='group.test';groups=groups or ['group.test']
        with zipfile.ZipFile(path,'w') as z:
            z.writestr(root+'Info.plist',plistlib.dumps(info));z.writestr(root+'Test',macho(groups,minimum,platform))
            if mode=='standard' and not missing:
                ext={'CFBundleIdentifier':'com.example.test.Broadcast','CFBundleExecutable':'Broadcast','AppGroupIdentifier':'group.test','NSExtension':{'NSExtensionPointIdentifier':'com.apple.broadcast-services-upload','NSExtensionPrincipalClass':'Broadcast.SampleHandler','RPBroadcastProcessMode':'RPBroadcastProcessModeSampleBuffer'}}
                z.writestr(root+'PlugIns/Broadcast.appex/Info.plist',plistlib.dumps(ext))
                z.writestr(root+'PlugIns/Broadcast.appex/Broadcast',macho(groups))
        return path
    def test_accepts_import_and_standard_packages(self):
        self.assertEqual(verify(self.package(),'import')['extensions'],0)
        self.assertEqual(verify(self.package('standard'),'standard')['extensions'],1)
    def test_rejects_missing_broadcast_extension(self):
        with self.assertRaises(ValueError): verify(self.package('standard',missing=True),'standard')
    def test_rejects_import_build_with_shared_entitlement(self):
        with self.assertRaises(ValueError): verify(self.package(groups=['group.test']),'import')
    def test_rejects_mismatched_shared_entitlement(self):
        with self.assertRaises(ValueError): verify(self.package('standard',groups=['group.wrong']),'standard')
    def test_rejects_non_ios_binary(self):
        with self.assertRaises(ValueError): verify(self.package(platform=1),'import')
    def test_rejects_deployment_above_target_phone(self):
        with self.assertRaises(ValueError): verify(self.package(minimum=26<<16),'import')

if __name__=='__main__': unittest.main()
