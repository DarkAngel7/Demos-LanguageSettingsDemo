//
//  DAViewController.m
//  LanguageSettingsDemo
//
//  Created by DarkAngel on 2017/5/4.
//  Copyright © 2017年 暗の天使. All rights reserved.
//

#import "DAViewController.h"

@interface DAViewController ()

@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation DAViewController

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.label.text = NSLocalizedString(@"这是一个国际化标题", nil);
}


@end
