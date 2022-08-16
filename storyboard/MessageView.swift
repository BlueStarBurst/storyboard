//
//  MessageView.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 8/14/22.
//

import SwiftUI
import UIKit

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif


class ChatLogViewModel: ObservableObject {
    @Published var chatName = ""
    @Published var chatMessages = [ChatMessage]()
    
    @Published var count: Int = 0
    
    func update() {
        
        chatName = DataHandler.shared.currentChatName
        chatMessages = DataHandler.shared.chatMessages
        count = chatMessages.count
    }
}



struct MessageView: View {
    
    static let emptyScrollToString = "Empty"
    
    @StateObject var model = ChatLogViewModel()
    
    enum Field: Hashable {
        case myField
    }
    
    @FocusState private var focusedField: Field?
    
    @State private var message: String?
    
    @State private var contentSize: CGSize = .zero
    
    init() {
        UITextView.appearance().backgroundColor = .clear
    }
    
    @State var lastUser = ""
    
    var body: some View {
        VStack {
            HStack {
                ZStack {
                    HStack {
                        Image(systemName: "chevron.backward")
                            .imageScale(.large)
                            .onTapGesture {
                                DataHandler.shared.hideMessages()
                            }
                        Spacer()
                    }
                    Text(model.chatName)
                    HStack {
                        Spacer()
                        Image(systemName: "person.2.fill")
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            
//            VStack {
//                Text(" ")
//                Spacer()
//            }
//            .frame(maxWidth: .infinity)
//            .background(Color.black)
//            .padding(.vertical, 10)
            
            
            ScrollView {
                ScrollViewReader { scrollViewProxy in
                    VStack {
                        if model.chatMessages.count > 0 {
                            ForEach(0...model.chatMessages.count-1, id: \.self) { num in
                                let thisUser = model.chatMessages[num]
                                if num < model.chatMessages.count-1 {
                                    let nextUser = model.chatMessages[num + 1]
                                    if (nextUser.fromId == thisUser.fromId) {
                                        TextBubble(message: thisUser, isUnique: false)
                                    } else {
                                        TextBubble(message: thisUser, isUnique: true)
                                    }
                                } else {
                                    TextBubble(message: thisUser, isUnique: true)
                                }
                            }
                        }
                        HStack { Spacer() }
                            .id(Self.emptyScrollToString)
                            
                    }
                    .onReceive(model.$count) { _ in
                        withAnimation(.easeOut(duration: 0.5)) {
                            scrollViewProxy.scrollTo(Self.emptyScrollToString,anchor: .bottom)
                        }
                    }
                    .padding(.top, 8)
                }
                
                
            }
            .background(Color(.init(white:0.10, alpha: 1)))
            
            HStack {
                Image(systemName: "camera.fill")
                    .imageScale(.large)
                
                
                    ScrollView {
                        ZStack(alignment: .topLeading) {
                            Color(red: 46.0/255, green: 46.0/255, blue: 46.0/255)
//                            Color.gray
                                .opacity(1)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Text(message ?? "Message")
                                .padding()
                                .opacity(message == nil ? 0.5 : 0)
                            TextEditor(text: Binding($message, replacingNilWith: ""))
                                .frame(minHeight: 30, alignment: .leading)
                                .cornerRadius(6.0)
                                .multilineTextAlignment(.leading)
                                .padding(9)
                                .opacity(1)
                        
                        }
                        .overlay(GeometryReader { geo in
                            Color.clear.opacity(0).onAppear {
                                contentSize = geo.size
                            }
                        })
                    }
                    .frame(maxHeight: contentSize.height)
                    
                
                
                Image(systemName: "paperplane.fill")
                    .opacity(message != "" && message != nil ? 1 : 0.5)
                    .frame(width: 20, height: 20)
                    .padding(.vertical)
                    .padding(.horizontal, 10)
                    .background(Color.pink.opacity(message != "" && message != nil ? 1 : 0.5))
                    .clipShape(Circle())
                    .onTapGesture {
                        if (message != "" && message != nil) {
                            DataHandler.shared.sendMessage(message: message ?? "")
                            message = ""
                        }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .padding(.top, 5)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 40.0/255, green: 40.0/255, blue: 40.0/255))
        .onTapGesture {
            self.hideKeyboard()
            focusedField = nil
        }
        .animation(.easeInOut)
        .transition(.move(edge: .bottom))
        .onAppear {
            DataHandler.shared.messageViewUpdate = model.update
            model.update()
        }
    }
    
}

struct TextBubble: View {
    
    let message: ChatMessage
    let isUnique: Bool
    
    var body: some View {
        if (message.fromId == DataHandler.shared.uid ?? "")
        {
            HStack {
                Spacer()
                VStack {
                    HStack {
                        Spacer()
                        HStack {
                            Text(message.text)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    if isUnique == true {
                        HStack {
                            Spacer()
                            Text(message.name)
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 15))
                        }
                    }
                }
                .padding(.bottom, 0)
            }
            .padding(.horizontal)
        } else {
            HStack {
                VStack {
                    HStack {
                        
                        HStack {
                            Text(message.text)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .background(Color(red: 46.0/255, green: 46.0/255, blue: 46.0/255))
                        .cornerRadius(8)
                        Spacer()
                    }
                    if isUnique == true {
                        HStack {
                            Text(message.name)
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 15))
                            Spacer()
                        }
                    }
                }
                .padding(.bottom, 0)
                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        MessageView()
    }
}


public extension Binding where Value: Equatable {
    
    init(_ source: Binding<Value?>, replacingNilWith nilProxy: Value) {
        self.init(
            get: { source.wrappedValue ?? nilProxy },
            set: { newValue in
                if newValue == nilProxy {
                    source.wrappedValue = nil
                } else {
                    source.wrappedValue = newValue
                }
            }
        )
    }
}
