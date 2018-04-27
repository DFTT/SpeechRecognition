//
//  STTSpeechRecognizerView.h
//  NativeEastNews
//
//  Created by 古月木四点 on 2017/5/19.
//  Copyright © 2017年 Gaoxin. All rights reserved.
//

#import <UIKit/UIKit.h>
// 需要音/视频 播放的时候监听，开始听写的时候视频or音频暂停，结束听写的时候继续播放
//开始听写
extern NSString *const VoiceListenStartNotification;
//结束听写
extern NSString *const VoiceListenStopNotification;

@interface STTSpeechRecognizerView : UIView

@property (nonatomic, assign) BOOL needPunctuation;
@property (nonatomic, copy) void(^speechRecComplete)(BOOL cancel,NSString *result);

- (void)start;

+ (void)checkAVAuthorizationStatus:(UIViewController *)viewcontroller complete:(void(^)(BOOL canUse))complete;
@end
