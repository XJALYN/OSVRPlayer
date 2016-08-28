//
//  XJDoubleScreenViewController.m
//  AVBasicVideoOutput
//
//  Created by xu jie on 16/6/16.
//  Copyright © 2016年 Apple. All rights reserved.
//

#import "XJVRPlayerViewController.h"

static void *AVPlayerItemStatusContext = &AVPlayerItemStatusContext;
@interface XJVRPlayerViewController ()
/// 创建一个播放器
@property(nonatomic,strong) AVPlayer *player;
/// 创建一个video 输出对象
@property(nonatomic,strong) AVPlayerItemVideoOutput *videoOutput;
/// 创建一个管理 video 输出对象 的队列
@property(nonatomic,strong) dispatch_queue_t myVideoOutputQueue;
/// 创建一个视频显示实图
@property(nonatomic,strong)OSOpenGLESViewController *displayVC;
/// 创建一个屏幕同步时间器
@property(nonatomic,strong) CADisplayLink *displayLink;
/// 创建一个播放工具栏
@property(nonatomic,strong) UIToolbar *toolbar;
/// 创建一个一个观察器，用于监测视频的播放时间
@property(nonatomic,strong) id timeObserver;
@property (weak, nonatomic) IBOutlet UIButton *ModeSwitch;
@property(nonatomic,assign)CGFloat lastDeltaY;

/*
 * 下面是一些界面上的空间，根据需求可自己定制
 */

@property (weak, nonatomic) IBOutlet UIView *downView;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;



@property (nonatomic)BOOL hideUpAndDownView;
@property(nonatomic,strong)id notificationToken;
@property(nonatomic,strong) NSURL *playUrl;
@property(nonatomic,strong)UIImageView *loginImageView;
@property(nonatomic,strong)UIImageView *adImageView;
@end

@implementation XJVRPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 初始化界面
    [self initUI];
    // 创建显示视频的view
    [self createPlayerView];
    // 创建播放器
    [self createPlayer];
    // 创建屏幕同步时间器
    [self createDisplayLink];
    // 设置avplayeritemvideooutput的pixelbuffer属性
    [self createVidoOutput];
    [self setupPlaybackForURL:self.playUrl];
   
    
}
- (void)viewWillAppear:(BOOL)animated
{
    [self addObserver:self forKeyPath:@"player.currentItem.status" options:NSKeyValueObservingOptionNew context:AVPlayerItemStatusContext];
    [self addTimeObserverToPlayer];
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self removeObserver:self forKeyPath:@"player.currentItem.status" context:AVPlayerItemStatusContext];
    [self removeTimeObserverFromPlayer];
    if (_notificationToken) {
        [[NSNotificationCenter defaultCenter] removeObserver:_notificationToken name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
        _notificationToken = nil;
    }
    
    [super viewWillDisappear:animated];
}

// MARK: - 初始化界面
-(void)initUI{
    self.hideUpAndDownView = false;
    self.ModeSwitch.layer.masksToBounds = true;
    self.ModeSwitch.layer.cornerRadius = self.ModeSwitch.bounds.size.height/2;
    self.closeButton.layer.masksToBounds = true;
    self.closeButton.layer.cornerRadius = self.closeButton.bounds.size.width/2;
    self.closeButton.layer.borderWidth = 1;
    self.closeButton.layer.borderColor = [UIColor colorWithRed:232/255.0 green:108/255.0 blue:40/255.0 alpha:1].CGColor;
    UIPanGestureRecognizer * pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(pan:)];
    [self.downView addGestureRecognizer:pan];
    
    
}
-(void)pan:(UIPanGestureRecognizer*)pan{
    if (pan.state == UIGestureRecognizerStateBegan){
        [self.player pause];
        if (!self.lastDeltaY){
             self.lastDeltaY = [pan locationInView:pan.view].x;
        }
       
        
    }else if (pan.state == UIGestureRecognizerStateChanged){
       
        CGFloat deltaY =  [pan locationInView:pan.view].x - self.lastDeltaY;
        
        CMTime time = self.player.currentItem.currentTime;
        time.value = time.value + time.timescale*deltaY/40;
        
        [self.player seekToTime:time];
        
        
    }else{
       [self.player play];
        self.lastDeltaY = 0;
    }
    
}


// MARK: - 创建显示视频的view
-(void)createPlayerView{
    // 显示视频界面
    self.displayVC = [[OSOpenGLESViewController alloc]initWithNibName:@"OSOpenGLESViewController" bundle:nil];
    self.displayVC.vedioType = self.vedioType;
    self.displayVC.view.frame = self.view.bounds;
    [self.view insertSubview:self.displayVC.view atIndex:0];
    [self.view insertSubview:self.loginImageView atIndex:1];
    // 加入login图片
    //[self.displayVC.view addSubview:self.loginImageView];
    
    [self addChildViewController:self.displayVC];
    
    
}

// MARK: - 创建播放器
-(void)createPlayer{
    self.player = [[AVPlayer alloc] init];
    // 监测播放器当前播放时间
    [self addTimeObserverToPlayer];
}
// MARK:- 给播放器增加时间监测功能
- (void)addTimeObserverToPlayer
{
    if (_timeObserver)
        return;
    /*
     使用弱引用防止重复引用
     */
    __weak XJVRPlayerViewController* weakSelf = self;
    _timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 10) queue:dispatch_get_main_queue() usingBlock:
                     
                     ^(CMTime time) {
                        
                         [weakSelf synTimeLabel:time];
                         
                     }];
}
// MAKR: 同步时间 显示在label上
-(void)synTimeLabel:(CMTime)time{
    NSInteger duration = self.player.currentItem.duration.value/self.player.currentItem.duration.timescale;
    NSInteger current = time.value/time.timescale;
    NSString *durationTime = [NSString stringWithFormat:@"%02ld:%02ld",duration/60,duration%60];
    NSString *currentTime = [NSString stringWithFormat:@"/%02ld:%02ld",current/60,current%60];
    self.timeLabel.text = [durationTime stringByAppendingString:currentTime];
    [self.progressView setProgress:current/(float)duration];
    
    if(self.player.rate == 0){
        [self.playPauseButton setBackgroundImage:[UIImage imageNamed: @"play.png"] forState:UIControlStateNormal];
        [self.displayVC.view addSubview:self.adImageView];
    }else{
        [self.playPauseButton setBackgroundImage:[UIImage imageNamed: @"pause.png"] forState:UIControlStateNormal];
        [self.adImageView removeFromSuperview];
    }
}


// 移除观察者
- (void)removeTimeObserverFromPlayer
{
    if (self.timeObserver)
    {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
}


// MARK: - 创建屏幕同步时间器
-(void)createDisplayLink{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.displayLink setPaused:YES];
}
// MARK: - 帧同步调用，获取像素缓冲区数据
- (void)displayLinkCallback:(CADisplayLink *)sender
{
    CMTime outputItemTime = kCMTimeInvalid;
    // 计算下下一同步时间，当屏幕下次刷新
    CFTimeInterval nextVSync = ([sender timestamp] + [sender duration]);
    outputItemTime = [[self videoOutput] itemTimeForHostTime:nextVSync];
    if ([self.videoOutput hasNewPixelBufferForItemTime:outputItemTime]) {
        CVPixelBufferRef pixelBuffer = NULL;
        pixelBuffer = [self.videoOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
        [self.displayVC displayPixelBuffer:pixelBuffer];
        
        if (pixelBuffer != NULL) {
            [self.loginImageView removeFromSuperview];
            CFRelease(pixelBuffer);
        }
    }
}

// MARK: - 创建Videoutput 及其配置
-(void)createVidoOutput{
    NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
    self.myVideoOutputQueue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoOutput  setDelegate:self queue:_myVideoOutputQueue];
}
// MARK: - AVPlayerItemOutputPullDelegate 代理回调
- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
{
    // 启动displayer.
    [[self displayLink] setPaused:NO];
}

- (void)setupPlaybackForURL:(NSURL *)URL
{
    
    // 初始化
    if ([self.player currentItem] == nil) {
       
        
    }
    // Remove video output from old item, if any.
    [[_player currentItem] removeOutput:self.videoOutput];
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:URL];
    AVAsset *asset = [item asset];
    
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        
        if ([asset statusOfValueForKey:@"tracks" error:nil] == AVKeyValueStatusLoaded) {
            NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
            if ([tracks count] > 0) {
                // Choose the first video track.  选择第一个video 进行跟踪
                AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
                [videoTrack loadValuesAsynchronouslyForKeys:@[@"preferredTransform"] completionHandler:^{
                    
                    if ([videoTrack statusOfValueForKey:@"preferredTransform" error:nil] == AVKeyValueStatusLoaded) {
                        CGAffineTransform preferredTransform = [videoTrack preferredTransform];
                        
                        /*
                         
                         定位的相机同时记录会影响图像的方向从一个avplayeritemvideooutput收到。在这里，我们计算一个旋转，用于正确定位视频
                         */
                        //self.displayVC.preferredRotation = -1 * atan2(preferredTransform.b, preferredTransform.a);
                        
                        
                        [self addDidPlayToEndTimeNotificationForPlayerItem:item];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [item addOutput:self.videoOutput];
                            [_player replaceCurrentItemWithPlayerItem:item];
                            // 调用这个方法 ，就会掉用回调方法  - (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
                            [self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
                            [self.player play];
                            
                        });
                        
                    }
                    
                }];
            }
        }
        
    }];
    
}
// MARK: - 添加播放结束通知
- (void)addDidPlayToEndTimeNotificationForPlayerItem:(AVPlayerItem *)item
{
    if (_notificationToken)
        _notificationToken = nil;

    _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    _notificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:item queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
    
        [[_player currentItem] seekToTime:kCMTimeZero];
    }];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == AVPlayerItemStatusContext) {
        AVPlayerStatus status = [change[NSKeyValueChangeNewKey] integerValue];
        NSLog(@"%ld",status);
        switch (status) {
            case AVPlayerItemStatusUnknown:
                break;
            case AVPlayerItemStatusReadyToPlay:
               // self.displayVC.presentationRect = [[_player currentItem] presentationSize];
                break;
            case AVPlayerItemStatusFailed:
                [self stopLoadingAnimationAndHandleError:[[_player currentItem] error]];
                break;
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
- (void)stopLoadingAnimationAndHandleError:(NSError *)error
{
    if (error) {
        NSString *cancelButtonTitle = NSLocalizedString(@"OK", @"Cancel button title for animation load error");
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription] message:[error localizedFailureReason] delegate:nil cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
        [alertView show];
    }
}
/*
 *手势
 */
- (IBAction)tapGesture:(id)sender {
    self.hideUpAndDownView = !self.hideUpAndDownView;
    if (self.hideUpAndDownView){
       
        self.downView.hidden = true;
        self.ModeSwitch.hidden = true;
        
        
    }else{
       
        self.downView.hidden = false;
        self.ModeSwitch.hidden = false;
    }
}


- (IBAction)playOrPause:(id)sender {
    
    if (self.player.rate == 0){
         [self.player play];
        
        
        
    }else{
        [self.player pause];
        
    }
    
   
    
}
- (IBAction)changeMode:(UIButton*)sender {
    self.displayVC.isVR = !self.displayVC.isVR;
    if (self.displayVC.isVR){
        if (self.vedioType == OSNormal){
            [sender setTitle:@"普通" forState:UIControlStateNormal];
        }else{
            [sender setTitle:@"全景" forState:UIControlStateNormal];
        }
        return;
    }
    [sender setTitle:@"VR" forState:UIControlStateNormal];
    
}

- (IBAction)close:(id)sender {
    [self dismissViewControllerAnimated:true completion:nil];
}



// 设置横屏现实
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

-(void)setVedioUrl:(NSURL *)url VedioType:(OSVedioType)type loginName:(NSString *)name{
    self.playUrl = url;
    self.vedioType = type;
    self.loginImageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:name]];
    self.loginImageView.frame = [UIScreen mainScreen].bounds;
    
}

-(void)setAdImageName:(NSString*)adName{
    self.adImageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:adName]];
    self.adImageView.frame = CGRectMake(0, 0, 200, 150);
    self.adImageView.center = CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2);
}


@end
