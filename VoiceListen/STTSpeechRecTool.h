//
//  STTSpeechRecTool.h
//  NativeEastNews
//
//  Created by 古月木四点 on 2017/8/23.
//  Copyright © 2017年 Gaoxin. All rights reserved.
//

#import <Foundation/Foundation.h>
@interface STTSpeechRecTool : NSObject
+ (void)displayOnViewController:(UIViewController *)viewController speechRecognizerResultHandel:(void(^)(NSString *))resultHandle;
@end
