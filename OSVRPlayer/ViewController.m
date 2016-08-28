//
//  ViewController.m
//  OSVRPlayer
//
//  Created by xu jie on 16/8/24.
//  Copyright © 2016年 xujie. All rights reserved.
//

#import "ViewController.h"
#import "XJVRPlayerViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *playButton1;
@property (weak, nonatomic) IBOutlet UIButton *playButton2;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.playButton1.layer.masksToBounds = true;
    self.playButton1.layer.cornerRadius = self.playButton1.bounds.size.width/2;
    
    self.playButton2.layer.masksToBounds = true;
    self.playButton2.layer.cornerRadius = self.playButton1.bounds.size.width/2;
   
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (IBAction)openPlayerVC:(id)sender {
    XJVRPlayerViewController *playerVC = [[XJVRPlayerViewController alloc]initWithNibName:@"XJVRPlayerViewController" bundle:nil];
     [playerVC setVedioUrl:[[NSBundle mainBundle] URLForResource:@"1" withExtension:@"mp4"] VedioType:OSPanorama loginName:@"login.png"];
     [playerVC setAdImageName:@"ad.png"];
    [self presentViewController:playerVC animated:true completion:nil];
   
}
- (IBAction)openPlayVC2:(id)sender {
    XJVRPlayerViewController *playerVC = [[XJVRPlayerViewController alloc]initWithNibName:@"XJVRPlayerViewController" bundle:nil];

    [playerVC setVedioUrl:[[NSBundle mainBundle] URLForResource:@"tang" withExtension:@"mov"] VedioType:OSNormal loginName:@"login.png"];
    [playerVC setAdImageName:@"ad.png"];
   
    [self presentViewController:playerVC animated:true completion:nil];
   
    
}

@end
