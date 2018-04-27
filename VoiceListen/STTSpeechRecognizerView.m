//
//  STTSpeechRecognizerView.m
//  NativeEastNews
//
//  Created by 古月木四点 on 2017/5/19.
//  Copyright © 2017年 Gaoxin. All rights reserved.
//

#import "STTSpeechRecognizerView.h"
#import "iflyMSC/IFlyMSC.h"
#import "MBProgressHUD+DL.h"
#import "AFNetworkReachabilityManager.h"
#import "STTCommentsRequestManager.h"
#import <AVFoundation/AVFoundation.h>
#import "UIAlertView+block.h"
#import "CommonHeader.h"

NSString *const VoiceListenStartNotification = @"VocieListenStartNotification";
NSString *const VoiceListenStopNotification  = @"VocieListenStopNotification";

@interface SoundWaveView : UIView
@property (nonatomic, copy) void (^itemLevelCallback)();
//
@property (nonatomic) CADisplayLink *displaylink;
@property (nonatomic) UIImageView *micImageView;
@property (nonatomic) NSUInteger numberOfItems;
@property (nonatomic) NSInteger level;

@property (nonatomic, strong) NSMutableArray * levelArray;//装载音量等级
@property (nonatomic) NSMutableArray * itemArray;//装载每个波纹
@property (nonatomic) CGFloat itemWidth;//每个波纹的宽度
@property (nonatomic) CGFloat itemSpace;//波纹间距
@property (nonatomic) NSArray *itemHeights;//波纹高度

- (void)startWave;
- (void)stopWave;
@end

@implementation SoundWaveView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)dealloc{
    [self.displaylink invalidate];
}

- (void)setup{
    
    self.itemArray = [NSMutableArray new];
    self.numberOfItems = 14;

    self.itemWidth  = 3;
    self.itemSpace  = 6;
    self.itemHeights  = @[@(3),@(10),@(17)];
    
    self.micImageView = [[UIImageView alloc] dk_initWithImagePicker:DKImageWithNames(@"voiceListen_mic_normal", @"voiceListen_mic_night")];
    [self addSubview:self.micImageView];
    [self.micImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
        make.bottom.with.top.equalTo(self);
    }];
    
    self.levelArray = [[NSMutableArray alloc]init];
    for(int i = 0 ; i < self.numberOfItems/2 ; i++){
        [self.levelArray addObject:@(0)];
    }
    
}

-(void)setItemLevelCallback:(void (^)())itemLevelCallback
{
    _itemLevelCallback = itemLevelCallback;
    
    CADisplayLink *displaylink = [CADisplayLink displayLinkWithTarget:_itemLevelCallback selector:@selector(invoke)];
    [displaylink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    displaylink.frameInterval = 6;
    displaylink.paused = YES;
    
    for(int i=0; i < self.numberOfItems; i++)
    {
        CAShapeLayer *itemline = [CAShapeLayer layer];
        itemline.fillColor     = DKColorWithRGB(0xf44b50, 0x55aaec)().CGColor;
        itemline.strokeColor   = nil;
        [self.layer addSublayer:itemline];
        
        [self.itemArray addObject:itemline];
    }
    
    self.displaylink = displaylink;
}

//根据讯飞返回 音量 0-30
- (void)setLevel:(NSInteger)level
{

    int waveLevel = level%10;

    if (waveLevel < 4) {
        waveLevel = 0;
    }else if (waveLevel>7){
        waveLevel = 2;
    }else{
        waveLevel = 1;
    }
    
    [self.levelArray removeLastObject];
    [self.levelArray insertObject:@(waveLevel) atIndex:0];
    [self.levelArray removeLastObject];
    [self.levelArray insertObject:@((waveLevel-1)<0?0:(waveLevel-1)) atIndex:1];

    
    [self updateItems];
    
}

- (void)updateItems
{
    
    UIGraphicsBeginImageContextWithOptions(self.frame.size, YES, 0);
    
    //3 10 17
    
    for (int i = (int)(self.numberOfItems/2)-1; i>=0; i--) {
        int level = [[self.levelArray objectAtIndex:i] intValue];
        float x = CGRectGetMinX(self.micImageView.frame)-13-self.itemWidth- (self.itemWidth+self.itemSpace) *((int)(self.numberOfItems/2)-1-i);
        CGRect rect = CGRectMake(x,
                                 (CGRectGetHeight(self.frame)-[self.itemHeights[level] integerValue])/2,
                                 self.itemWidth,
                                 [self.itemHeights[level] integerValue]
                                 );
        UIBezierPath *itemLinePath = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:1.5];
        [itemLinePath fill];
        CAShapeLayer *itemLine = [self.itemArray objectAtIndex:i];
        itemLine.path = [itemLinePath CGPath];
        
    }
    
    
    for (int i = (int)self.numberOfItems/2; i<self.numberOfItems; i++) {
        int level = [[self.levelArray objectAtIndex:self.levelArray.count - (i-self.levelArray.count)-1] intValue];
        float x = CGRectGetMaxX(self.micImageView.frame)+13+(self.itemWidth+self.itemSpace) * (i-self.numberOfItems/2);
        CGRect rect = CGRectMake(x,
                                 (CGRectGetHeight(self.frame)-[self.itemHeights[level] integerValue])/2,
                                 self.itemWidth,
                                 [self.itemHeights[level] integerValue]
                                 );
        UIBezierPath *itemLinePath = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:1.5];
        CAShapeLayer *itemLine = [self.itemArray objectAtIndex:i];
        [itemLinePath fill];
        itemLine.path = [itemLinePath CGPath];
    }
    
    UIGraphicsEndImageContext();
}

- (void)startWave{
    self.displaylink.paused = NO;
}

- (void)stopWave{
    self.displaylink.paused = YES;
    for (int i = 0; i < self.levelArray.count; i++) {
        [self.levelArray replaceObjectAtIndex:i withObject:@(0)];
    }
    [self updateItems];
}

@end




@interface STTSpeechRecognizerView ()<IFlySpeechRecognizerDelegate>
@property (nonatomic, copy) void(^tipLableStr)(NSString *);
@property (nonatomic, strong) IFlySpeechRecognizer *iFlySpeechRecognizer;
@property (nonatomic, assign) BOOL                  isCanceled;
@property (nonatomic)   NSString             *resultStr;

@property (nonatomic) UIButton *speechFinishBtn;
@property (nonatomic) UIControl *speechClose;
@property (nonatomic) SoundWaveView *wave;

@property (nonatomic) NSDate   *speechStartDate;
@property (nonatomic, assign) float speechInterval;
@property (nonatomic, assign) int volume;

@property (nonatomic, copy) NSString *voiceCachePath;
/*这俩货只是用来更新识别中的动效*/
@property (nonatomic) CADisplayLink *displayLink;
@property (nonatomic, assign) int idx;
@end

@implementation STTSpeechRecognizerView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.dk_backgroundColorPicker = DKColorWithRGB(0xffffff, 0x212121);
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(recognizingAnimation:)];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        _displayLink.frameInterval = 20;
        _displayLink.paused = YES;
        
        
        //监听回到后台
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActiveNotification:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachePath = [paths objectAtIndex:0];
        _voiceCachePath = [[NSString alloc] initWithFormat:@"%@",[cachePath stringByAppendingPathComponent:@"voice.pcm"]];
    }
    return self;
}

- (void)applicationWillResignActiveNotification:(NSNotification *)notfi{
    
    BLOCK_EXEC(self.speechRecComplete,YES,nil);
    
    [_iFlySpeechRecognizer cancel];
    [_iFlySpeechRecognizer setDelegate:nil];
    [_iFlySpeechRecognizer setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
    [_displayLink invalidate];
    
}


#pragma mark  初始化语音识别对象
- (void)initRecognizer{
    if (_iFlySpeechRecognizer == nil) {
        _iFlySpeechRecognizer = [IFlySpeechRecognizer sharedInstance];
        
        [_iFlySpeechRecognizer setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
        
        //设置听写模式
        [_iFlySpeechRecognizer setParameter:@"iat" forKey:[IFlySpeechConstant IFLY_DOMAIN]];
    }
    _iFlySpeechRecognizer.delegate = self;
    
    if (_iFlySpeechRecognizer) {
        
        //设置最长录音时间
        [_iFlySpeechRecognizer setParameter:@"60000" forKey:[IFlySpeechConstant SPEECH_TIMEOUT]];
        
        //设置语音前端点:静音超时时间，即用户多长时间不说话则当做超时处理1000~10000
        [_iFlySpeechRecognizer setParameter:@"8000" forKey:[IFlySpeechConstant VAD_BOS]];
        
        //设置语音后端点:后端点静音检测时间，即用户停止说话多长时间内即认为不再输入， 自动停止录音0~10000
        [_iFlySpeechRecognizer setParameter:@"2000" forKey:[IFlySpeechConstant VAD_EOS]];
        
        //采样率
        [_iFlySpeechRecognizer setParameter:@"16000" forKey:[IFlySpeechConstant SAMPLE_RATE]];
        
        //网络请求 超时时间
        [_iFlySpeechRecognizer setParameter:@"5000" forKey:[IFlySpeechConstant NET_TIMEOUT]];
        
        // 设置是否有标点符号
        [_iFlySpeechRecognizer setParameter:_needPunctuation?@"1":@"0" forKey:[IFlySpeechConstant ASR_PTT]];
        
        //设置语音识别完成后数据返回数据结构类型
        
    }

}



#pragma mark  UI 界面
- (void)drawRect:(CGRect)rect{
    
    UIControl *close = [[UIControl alloc] init];
    [self addSubview:close];
    [close mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self);
        make.top.equalTo(self);
    }];
    
    UIImageView *closeimg = [[UIImageView alloc] dk_initWithImagePicker:DKImageWithNames(@"voiceListen_close_normal", @"voiceListen_close_night")];
    [close addSubview:closeimg];
    [closeimg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(close).offset(15);
        make.right.equalTo(close).offset(-15);
        make.left.equalTo(close).offset(15);
        make.bottom.equalTo(close).offset(-15);
    }];
    [close addTarget:self action:@selector(cancelSpeech) forControlEvents:UIControlEventTouchUpInside];
    
    self.speechClose = close;
    
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:16];
    label.text = @"正在录制，请说话";
    label.dk_textColorPicker = DKColorWithRGB(0x333333, 0x888888);
    [self addSubview:label];
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self).offset(48);
        make.centerX.equalTo(self);
    }];
    
    [self setTipLableStr:^(NSString *str){
        label.text = str;
    }];
    

    SoundWaveView *soundWave = [[SoundWaveView alloc] init];
    [self addSubview:soundWave];
    [soundWave mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(label.mas_bottom).offset(21);
        make.centerX.equalTo(self);
        make.width.mas_equalTo(self).multipliedBy(0.8);
    }];
    
    __weak typeof(soundWave)weakSoundWave = soundWave;
    WEAK_Self
    soundWave.itemLevelCallback = ^{
        weakSoundWave.level = weakSelf.volume;
    };
    
    self.wave = soundWave;
    
    UIButton *over = [[UIButton alloc] init];
    [over setTitle:@"我讲完了" forState:UIControlStateNormal];
    over.titleLabel.font = [UIFont systemFontOfSize:17];
    [over dk_setTitleColorPicker:DKColorWithRGB(0xf44b50, 0x888888) forState:UIControlStateNormal];
    [self addSubview:over];
    [over mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.right.equalTo(self);
        make.width.equalTo(self);
        make.bottom.equalTo(self);
        make.height.mas_equalTo(50);
    }];
    
    [over addTarget:self action:@selector(overSpeech) forControlEvents:UIControlEventTouchUpInside];
    self.speechFinishBtn = over;
    
    
    UIView *line = [[UIView alloc] init];
    line.dk_backgroundColorPicker = DKColorWithRGB(0xe8e8e8, 0x292929);
    [self addSubview:line];
    [line mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.width.equalTo(self);
        make.height.equalTo(@(0.5));
        make.bottom.equalTo(over.mas_top);
    }];
    
    self.layer.cornerRadius = 15;
    self.layer.masksToBounds = YES;
    
    
}

#pragma mark  开始听写
- (void)startSpeech{
    
    self.speechFinishBtn.enabled = YES;
    self.isCanceled = NO;
    if (!_iFlySpeechRecognizer) {
        [self initRecognizer];
    }
    
    [_iFlySpeechRecognizer cancel];
    //设置音频来源为麦克风
    [_iFlySpeechRecognizer setParameter:IFLY_AUDIO_SOURCE_MIC forKey:@"audio_source"];
    //设置听写结果格式为json
    [_iFlySpeechRecognizer setParameter:@"json" forKey:[IFlySpeechConstant RESULT_TYPE]];
    //设置在document文件夹下存储的文件名
    [_iFlySpeechRecognizer setParameter:@"voice.pcm" forKey:[IFlySpeechConstant ASR_AUDIO_PATH]];
    [_iFlySpeechRecognizer setDelegate:self];
    
    if ([_iFlySpeechRecognizer startListening]) {
        
        self.speechStartDate = [NSDate date];
        self.speechInterval = 0;
        BLOCK_EXEC(self.tipLableStr,@"正在录制，请说话");
        
    }else{
        [MBProgressHUD showError:@"启动识别服务失败，请稍后重试" toView:nil hudConfig:nil];
        BLOCK_EXEC(self.speechRecComplete,YES,nil);
        [self hide];
    }
    
}

#pragma mark  关闭 识别窗口
- (void)cancelSpeech{

    self.isCanceled = YES;
    BLOCK_EXEC(self.speechRecComplete,YES,nil);
    [self hide];
    
    [UpLogManager uplogButtonStatistics:Audio_Comment_Btn_Cancel andDescription:nil];
}


#pragma mark 我讲完了
- (void)overSpeech{
    
    self.speechFinishBtn.enabled = NO;
    [self recognizingAnimation:nil];
    _displayLink.paused = NO;

    self.speechInterval = [[NSDate date] timeIntervalSinceDate:self.speechStartDate];
    [_iFlySpeechRecognizer stopListening];
    
    [UpLogManager uplogButtonStatistics:Audio_Comment_Btn_Finish andDescription:nil];
}


- (void)recognizingAnimation:(CADisplayLink *)link{
    NSArray *arr = @[@"正在识别中",@"正在识别中.",@"正在识别中..",@"正在识别中..."];
    if (_idx>arr.count-1) {
        _idx = 0;
    }
    BLOCK_EXEC(self.tipLableStr, arr[_idx]);
    _idx ++;
}



#pragma mark -- 初始化

- (void)start{
        [[NSNotificationCenter defaultCenter] postNotificationName:VoiceListenStartNotification object:nil];
        NSLog(@"———————— 调起语音识别 （监测是否释放语音识别）———————————");

        [self initRecognizer];
        [self startSpeech];
}



- (void)hide{
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        [_iFlySpeechRecognizer cancel];
        [_iFlySpeechRecognizer setDelegate:nil];
        [_iFlySpeechRecognizer setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
        [_displayLink invalidate];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:VoiceListenStopNotification
                                                                object:nil];

        });
    });
}




#pragma mark - #######IFlySpeechRecognizerDelegate
- (void)onVolumeChanged:(int)volume{
    self.volume =  volume;
}

/**
 停止录音回调
 */
- (void)onEndOfSpeech{
    [self.wave stopWave];
    if (self.speechInterval == 0) {
        self.speechInterval = [[NSDate date] timeIntervalSinceDate:self.speechStartDate];
    }
    NSLog(@"--------------------------------\n 停止识别 \n");
}


/**
 开始录音回调
 */
- (void)onBeginOfSpeech{
    [self.wave startWave];
    NSLog(@"---------------------------------\n 开始识别 \n");
}


- (void)onCancel{
    [self.wave stopWave];
    NSLog(@"--------------------------------\n 取消识别 \n");
}


- (void)onError:(IFlySpeechError *)error{
    
    _displayLink.paused = YES;
    
    if (self.isCanceled) {
        
    }
    else if (error.errorCode == 0){
       
        /*-----*/
        if (_resultStr.length > 0) {
            
            /*
             * 这一步是对讯飞识别结果做一个容错（有时候不管是否设置需要标点符号，识别结果会出现只有一个句号的情况）
             */
            NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@".,。，"];
            NSString *trimStr = [_resultStr stringByTrimmingCharactersInSet:set];
            if (trimStr.length == 0) {
                _resultStr = trimStr;
            }else{
                if (!_needPunctuation) {
                    _resultStr = trimStr;
                }
            }
        }
        /*----*/
        
        if (self.speechInterval<1) {
            BLOCK_EXEC(self.tipLableStr,@"录音时间太短，请重新录音");
            WEAK_Self
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (weakSelf.iFlySpeechRecognizer.delegate) {
                    [weakSelf startSpeech];
                }
            });
            return;
        }
        
        if (_resultStr.length == 0) {
            BLOCK_EXEC(self.tipLableStr,@"未识别到声音，请靠近话筒说话" );
            WEAK_Self
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (weakSelf.iFlySpeechRecognizer.delegate) {
                    [weakSelf startSpeech];
                }
            });
            return;
        }
        
        BLOCK_EXEC(self.speechRecComplete,NO,_resultStr);
        [self hide];

        WEAK_Self
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [weakSelf sendVoiceThread:weakSelf.resultStr];
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.resultStr = nil;
            });
        });
        
        
    }else{
        
        if (error.errorCode == 10118) {
            BLOCK_EXEC(self.tipLableStr, @"未识别到声音，请靠近话筒说话");
            WEAK_Self
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (weakSelf.iFlySpeechRecognizer.delegate) {
                    [weakSelf startSpeech];
                }
            });
            return;
        }
        
        [MBProgressHUD showError:@"网络错误，请稍候重试" toView:nil hudConfig:nil];
        BLOCK_EXEC(self.speechRecComplete,YES,nil);
        [self hide];
    }
    
}

- (void)onResults:(NSArray *)results isLast:(BOOL)isLast{
    
    NSMutableString *resultString = [[NSMutableString alloc] init];
    NSDictionary *dic = results[0];
    for (NSString *key in dic) {
        [resultString appendFormat:@"%@",key];
    }
    
    NSString * resultFromJson =  [self stringFromJson:resultString];
    _resultStr = [NSString stringWithFormat:@"%@%@",_resultStr?:@"",resultFromJson];
}

- (void)onEvent:(int)eventType arg0:(int)arg0 arg1:(int)arg1 data:(NSData *)eventData{
    
}

/**
 解析听写json格式的数据
 params例如：
 {"sn":1,"ls":true,"bg":0,"ed":0,"ws":[{"bg":0,"cw":[{"w":"白日","sc":0}]},{"bg":0,"cw":[{"w":"依山","sc":0}]},{"bg":0,"cw":[{"w":"尽","sc":0}]},{"bg":0,"cw":[{"w":"黄河入海流","sc":0}]},{"bg":0,"cw":[{"w":"。","sc":0}]}]}
 ****/
- (NSString *)stringFromJson:(NSString*)params
{
    if (params == NULL) {
        return nil;
    }
    
    NSMutableString *tempStr = [[NSMutableString alloc] init];
    NSDictionary *resultDic  = [NSJSONSerialization JSONObjectWithData:    //返回的格式必须为utf8的,否则发生未知错误
                                [params dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    
    if (resultDic!= nil) {
        NSArray *wordArray = [resultDic objectForKey:@"ws"];
        
        for (int i = 0; i < [wordArray count]; i++) {
            NSDictionary *wsDic = [wordArray objectAtIndex: i];
            NSArray *cwArray = [wsDic objectForKey:@"cw"];
            
            for (int j = 0; j < [cwArray count]; j++) {
                NSDictionary *wDic = [cwArray objectAtIndex:j];
                NSString *str = [wDic objectForKey:@"w"];
                [tempStr appendString: str];
            }
        }
    }
    return tempStr;
}

#pragma mark ----  检测麦克风权限
+ (void)checkAVAuthorizationStatus:(UIViewController *)viewcontroller complete:(void (^)(BOOL))complete{
    [self testMicrophonePermissions:^(BOOL enable) {
        BLOCK_EXEC(complete, enable);
        if (!enable) {
            NSString *message = [[NSString alloc] initWithFormat:@"请到 设置-%@-麦克风\n对%@进行授权",AppChinaName,AppChinaName];
            UIAlertController *alter = [UIAlertController alertControllerWithTitle:@"无法访问麦克风" message:message preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *action1 = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
            UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                if([[UIApplication sharedApplication] canOpenURL:url]){
                    [[UIApplication sharedApplication] openURL:url];
                }
            }];
            [alter addAction:action1];
            [alter addAction:action2];
            [viewcontroller presentViewController:alter animated:YES completion:nil];
        }
    }];
}


+ (void)testMicrophonePermissions:(void(^)(BOOL enable))enable{
    
    AVAuthorizationStatus statusAudio = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    
    switch (statusAudio) {
            //用户明确不允许应用访问麦克风
        case AVAuthorizationStatusDenied:
            BLOCK_EXEC(enable,NO);
            break;
            //用户明确允许应用访问麦克风
        case AVAuthorizationStatusAuthorized:
            BLOCK_EXEC(enable,YES);
            break;
            //应用没有被授权麦克风权限（plist文件没有设置）
        case AVAuthorizationStatusRestricted:
            break;
            //用户还没有对应用设置权限 (安装后首次打开)
        case AVAuthorizationStatusNotDetermined:
        {
            [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
                
                //这个地方 需要返回主线程
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (granted) {
                        NSLog(@"用户点了允许");
                        BLOCK_EXEC(enable,YES);
                    }else{
                        NSLog(@"用户点了不允许");
                    }

                });
            }];
        }
            break;
        default:
            break;
    }
}


#pragma mark  --- 上传语音文件
- (void)sendVoiceThread:(NSString *)content{
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if(!_voiceCachePath || [_voiceCachePath length] == 0 || !content) {
        return;
    }
    if (![fm fileExistsAtPath:_voiceCachePath]) {
        return;
    }
    NSData *data = [NSData dataWithContentsOfFile:_voiceCachePath];    //从文件中读取音频
    [STTCommentsRequestManager uploadVoiceCommentsContentData:data content:content];
}

@end
