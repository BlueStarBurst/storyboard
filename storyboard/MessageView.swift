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

struct MessageView: View {
    
    enum Field: Hashable {
        case myField
    }
    
    @FocusState private var focusedField: Field?
    
    @State private var message: String?
    
    @State private var contentSize: CGSize = .zero
    
    init() {
        UITextView.appearance().backgroundColor = .clear
    }
    
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
                    Text("Chatroom")
                    HStack {
                        Spacer()
                        Image(systemName: "person.2.fill")
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            VStack {
                Text(" ")
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .padding(.vertical, 10)
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
                    .frame(width: 20, height: 20)
                    .padding(.vertical)
                    .padding(.horizontal, 10)
                    .background(Color.pink)
                    .clipShape(Circle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 40.0/255, green: 40.0/255, blue: 40.0/255))
        .onTapGesture {
            self.hideKeyboard()
            focusedField = nil
        }
        .animation(.easeInOut)
        .transition(.move(edge: .bottom))
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
