import SwiftUI
import ScrollShotCore
struct ImageEditorView:View {
    @EnvironmentObject private var model:AppModel
    @Environment(\.dismiss) private var dismiss
    let session:SessionManifest
    @State private var mode="browse"
    @State private var edits:[PageEdit]=[]
    private var pages:[StitchSegment] {
        let frames=session.previewFrames.isEmpty ? session.frames:session.previewFrames
        guard let segments=try? StitchPlanner.build(records:frames,crop:session.crop) else {return []}
        return (try? StitchPlanner.pages(segments:segments,outer:session.outerCrop)) ?? []
    }
    var body:some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing:16) {
                    Text("先浏览到目标位置，再切换工具拖动框选。绿色框是保留范围，灰块是马赛克区域；应用后查看最终图片。原始帧保留。 ").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                    ForEach(Array(pages.enumerated()),id:\.offset) {index,page in
                        if edits.indices.contains(index) {
                            EditablePageView(page:page,index:index,directory:model.store.directory(for:session.id),edit:$edits[index],mode:mode)
                        }
                    }
                }.padding(.vertical)
            }.scrollDisabled(mode != "browse").scrollDismissesKeyboard(.interactively)
                .navigationTitle("马赛克与裁剪").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) {Button("取消"){dismiss()}.accessibilityIdentifier("image.cancel")}
                    ToolbarItem(placement:.confirmationAction) {Button("应用"){if model.export(session.id,crop:session.crop,outer:session.outerCrop,edits:edits,removeScrollbar:session.scrollbarRemoval ?? model.toolPreferences.smartScrollbar) {dismiss()}}.disabled(model.busy || model.savingPhotos || edits.count != pages.count).accessibilityIdentifier("image.apply")}
                }
                .safeAreaInset(edge:.bottom) {
                    Picker("工具",selection:$mode) {Text("浏览").tag("browse");Text("马赛克").tag("mosaic");Text("裁剪").tag("crop")}.pickerStyle(.segmented).padding().background(.regularMaterial).accessibilityIdentifier("image.mode")
                }
                .onAppear {edits=session.pageEdits?.count==pages.count ? session.pageEdits! : Array(repeating:PageEdit(),count:pages.count)}
                .alert("轻卷截图",isPresented:Binding(get:{model.message != nil},set:{if !$0 {model.message=nil}})) {Button("知道了"){model.message=nil}} message:{Text(model.message ?? "")}
        }
    }
}
private struct EditablePageView:View {
    let page:StitchSegment
    let index:Int
    let directory:URL
    @Binding var edit:PageEdit
    let mode:String
    @State private var drag:PixelRect?
    var body:some View {
        VStack(spacing:10) {
            HStack {Text("第 \(index+1) 张 · \(page.width) × \(page.height)").font(.caption.monospacedDigit());Spacer();Button("还原本张"){edit=PageEdit()}.font(.caption)}.padding(.horizontal)
            HStack {Button("撤销一块马赛克"){if !edit.mosaics.isEmpty {edit.mosaics.removeLast()}}.disabled(edit.mosaics.isEmpty);Spacer();Button("取消裁剪"){edit.crop=nil}.disabled(edit.crop==nil)}.font(.caption).padding(.horizontal)
            DisclosureGroup("四边裁剪（像素）") {
                HStack {insetField("左",axis:0);insetField("右",axis:1);insetField("上",axis:2);insetField("下",axis:3)}
            }.font(.caption).padding(.horizontal)
            GeometryReader {geo in
                let scale=geo.size.width/CGFloat(page.width)
                ZStack(alignment:.topLeading) {
                    LazyVStack(spacing:0) {
                        ForEach(Array(page.pieces.enumerated()),id:\.offset) {_,piece in
                            PieceThumbnail(url:directory.appendingPathComponent(piece.fileName),piece:piece,width:page.width,maxPixelSize:1800)
                        }
                    }
                    ForEach(Array(edit.mosaics.enumerated()),id:\.offset) {_,rect in
                        Rectangle().fill(Color.gray).overlay {Image(systemName:"square.grid.3x3.fill").foregroundStyle(.white)}
                            .frame(width:CGFloat(rect.width)*scale,height:CGFloat(rect.height)*scale)
                            .position(x:CGFloat(rect.x)*scale+CGFloat(rect.width)*scale/2,y:CGFloat(rect.y)*scale+CGFloat(rect.height)*scale/2)
                    }
                    if let crop=edit.crop {outline(crop,scale:scale,color:.green)}
                    if let drag {outline(drag,scale:scale,color:mode=="crop" ? .green:.orange)}
                }.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance:5).onChanged {value in drag=selection(value,scale:scale)}.onEnded {value in
                        if let rect=selection(value,scale:scale) {if mode=="mosaic" {edit.mosaics.append(rect)} else if mode=="crop" {edit.crop=rect}}
                        drag=nil
                    },including:mode=="browse" ? .none:.all)
            }.aspectRatio(CGFloat(page.width)/CGFloat(page.height),contentMode:.fit)
        }
    }
    private func outline(_ rect:PixelRect,scale:CGFloat,color:Color)->some View {
        Rectangle().stroke(color,lineWidth:3).frame(width:CGFloat(rect.width)*scale,height:CGFloat(rect.height)*scale)
            .position(x:CGFloat(rect.x)*scale+CGFloat(rect.width)*scale/2,y:CGFloat(rect.y)*scale+CGFloat(rect.height)*scale/2).allowsHitTesting(false)
    }
    private func selection(_ value:DragGesture.Value,scale:CGFloat)->PixelRect? {
        guard scale>0 else {return nil}
        let x=max(0,min(page.width-1,Int(min(value.startLocation.x,value.location.x)/scale)))
        let y=max(0,min(page.height-1,Int(min(value.startLocation.y,value.location.y)/scale)))
        let right=max(x+1,min(page.width,Int(max(value.startLocation.x,value.location.x)/scale)))
        let bottom=max(y+1,min(page.height,Int(max(value.startLocation.y,value.location.y)/scale)))
        guard right-x>=2,bottom-y>=2 else {return nil};return PixelRect(x:x,y:y,width:right-x,height:bottom-y)
    }
    private func insetField(_ name:String,axis:Int)->some View {
        VStack {Text(name);TextField(name,text:Binding(get:{String(inset(axis))},set:{setInset(axis,text:$0)})).keyboardType(.numberPad).textFieldStyle(.roundedBorder).multilineTextAlignment(.center)}
    }
    private func inset(_ axis:Int)->Int {
        let r=edit.crop ?? PixelRect(x:0,y:0,width:page.width,height:page.height)
        switch axis {case 0:return r.x;case 1:return page.width-r.x-r.width;case 2:return r.y;default:return page.height-r.y-r.height}
    }
    private func setInset(_ axis:Int,text:String) {
        guard let number=Int(text),number>=0 else {return}
        var l=inset(0),r=inset(1),t=inset(2),b=inset(3)
        switch axis {case 0:l=min(number,page.width-r-1);case 1:r=min(number,page.width-l-1);case 2:t=min(number,page.height-b-1);default:b=min(number,page.height-t-1)}
        edit.crop=PixelRect(x:l,y:t,width:page.width-l-r,height:page.height-t-b)
    }
}
