//
//  XJDoubleScreenViewController.h
//  AVBasicVideoOutput
//
//  Created by xu jie on 16/6/16.
//  Copyright © 2016年 Apple. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OSOpenGLESViewController.h"
#import <AVFoundation/AVFoundation.h>
# define ONE_FRAME_DURATION 0.03
@interface XJVRPlayerViewController : UIViewController <AVPlayerItemOutputPullDelegate>
@property(nonatomic,assign)OSVedioType vedioType;

-(void)setVedioUrl:(NSURL*)url VedioType:(OSVedioType)type loginName:(NSString *)name;
-(void)setAdImageName:(NSString*)adName;

@end
