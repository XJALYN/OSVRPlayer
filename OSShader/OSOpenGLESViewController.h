//
//  OSOpenGLESViewController.h
//  OpenGLES_Shader_003
//
//  Created by xu jie on 16/8/23.
//  Copyright © 2016年 xujie. All rights reserved.
//

#import <GLKit/GLKit.h>
typedef NS_ENUM (NSInteger,OSVedioType){
    OSNormal, //  普通视频
    OSPanorama // 默认为全景视频
};

@protocol OSOpenGLESViewControllerDelegate <NSObject>
-(void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

@interface OSOpenGLESViewController : GLKViewController  <OSOpenGLESViewControllerDelegate>
@property(nonatomic,assign)OSVedioType vedioType;

@property(nonatomic,assign)BOOL isVR;



@end


