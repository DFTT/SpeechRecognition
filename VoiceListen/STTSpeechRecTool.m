//
//  STTSpeechRecTool.m
//  NativeEastNews
//
//  Created by 古月木四点 on 2017/8/23.
//  Copyright © 2017年 Gaoxin. All rights reserved.
//

#import "STTSpeechRecTool.h"
#import "AppDelegate.h"
#import "STTSpeechRecognizerView.h"
#import <AVFoundation/AVFoundation.h>
#import "UIAlertView+block.h"
@interface STTSpeechRecViewController:UIViewController
@property (nonatomic) STTSpeechRecognizerView *speechRecView;
@property (nonatomic, copy) void(^speechRecResult)(NSString *);
@end
@implementation STTSpeechRecViewController
- (void)viewDidLoad{
    [super viewDidLoad];
    self.view.backgroundColor = ColorWithHexA(0x000000, 0.3);
    
    self.speechRecView = [[STTSpeechRecognizerView alloc] init];
    [self.view addSubview:self.speechRecView];
    [self.speechRecView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(280);
        make.height.mas_equalTo(230);
        make.center.equalTo(self.view);
    }];
    
    WEAK_Self
    self.speechRecView.speechRecComplete = ^(BOOL cancel, NSString *result) {
        [weakSelf dismissViewControllerAnimated:YES completion:^{
            if (result) {
                BLOCK_EXEC(weakSelf.speechRecResult, result);
            }
        }];
    };
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    self.speechRecView.transform = CGAffineTransformMakeScale(0, 0);
    
    WEAK_Self
    [UIView animateWithDuration:0.2
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         weakSelf.speechRecView.transform = CGAffineTransformMakeScale(1, 1);
                     } completion:^(BOOL finished) {
                         if (finished) {
                              [weakSelf.speechRecView start];
                         }
                     }];
    
}


@end

@implementation STTSpeechRecTool
+ (void)displayOnViewController:(UIViewController *)viewController speechRecognizerResultHandel:(void (^)(NSString *))resultHandle{
    UIViewController *presentingVC = viewController;
    if (viewController.presentedViewController) {
        presentingVC = viewController.presentedViewController;
    }
    [presentingVC.view endEditing:YES];
    [STTSpeechRecognizerView checkAVAuthorizationStatus:presentingVC complete:^(BOOL canUse) {
        if (canUse) {
            if ([AFNetworkReachabilityManager sharedManager].networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
                [MBProgressHUD showError:@"网络错误，请稍候重试" toView:nil hudConfig:nil];
                return ;
            }
            STTSpeechRecViewController *inputVC = [[STTSpeechRecViewController alloc] init];
            inputVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
            inputVC.modalTransitionStyle   = UIModalTransitionStyleCrossDissolve;
            inputVC.speechRecResult = resultHandle;
            [presentingVC presentViewController:inputVC animated:YES completion:nil];
        }
    }];
}


@end
