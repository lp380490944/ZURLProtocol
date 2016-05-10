//
//  ViewController.m
//  URLProtocolDemo
//
//  Created by zly on 16/5/10.
//  Copyright © 2016年 zly. All rights reserved.
//

#import "ViewController.h"
#import "ZURLProtocol/ZURLProtocol.h"

@interface ViewController ()
@property (nonatomic, strong) UIWebView *webView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //开启缓存
    [ZURLProtocol Init];
    
    CGSize szbounds  = self.view.bounds.size;
    
    CGRect rcWebView = CGRectMake(0,0,szbounds.width, szbounds.height);
    self.webView = [[UIWebView alloc]initWithFrame:rcWebView];
    [self.view addSubview:self.webView];
    
    NSMutableURLRequest *request= [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://image.baidu.com/"]];
    
    [self.webView loadRequest:request];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
