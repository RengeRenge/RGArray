//
//  ViewController.m
//  RGArray
//
//  Created by renge on 2020/4/20.
//  Copyright © 2020 renge. All rights reserved.
//

#import "ViewController.h"
#import "RGArray.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, RGArrayChangeDelegate>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UITextField *inputView;

@property (nonatomic, strong) UIButton *random;
@property (nonatomic, strong) UIButton *add;
@property (nonatomic, strong) UIButton *remove;
@property (nonatomic, strong) UIButton *set;

@property (nonatomic, strong) UIButton *autoTest;

@property (nonatomic, strong) UIStackView *buttonWrapper;

@property (nonatomic, strong) RGArray <NSString *> *array;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.array = [RGArray arrayWithObjects:@"1", @"6", @"4", nil];
    
    [self.array addDelegate:self];
    [self.array setEqualRule:^BOOL(NSString * _Nonnull obj, NSString * _Nonnull other) {
        return [obj isEqualToString:other];
    }];
    
    [self.array setModifyRule:^BOOL(NSString * _Nonnull old, NSString * _Nonnull young) {
        return ![old isEqualToString:young];
    }];
    
    UITableView *tableView = [[UITableView alloc] init];
    tableView.dataSource = self;
    tableView.delegate = self;
    [tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"111"];
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:tableView];
    self.tableView = tableView;
    
    
    self.random = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.random setTitle:@"random" forState:UIControlStateNormal];
    
    self.add = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.add setTitle:@"add" forState:UIControlStateNormal];
    
    self.remove = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.remove setTitle:@"remove" forState:UIControlStateNormal];
    
    self.set = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.set setTitle:@"set" forState:UIControlStateNormal];
    
    self.autoTest = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.autoTest setTitle:@"auto" forState:UIControlStateNormal];
    
    NSArray <UIButton *> *views = @[self.random, self.add, self.remove, self.set, self.autoTest];
    [views enumerateObjectsUsingBlock:^(UIButton * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj sizeToFit];
    }];
    self.buttonWrapper = [[UIStackView alloc] initWithArrangedSubviews:views];
    self.buttonWrapper.alignment = UIStackViewAlignmentFill;
    self.buttonWrapper.distribution = UIStackViewDistributionEqualSpacing;
    self.buttonWrapper.spacing = 10;
    [self.view addSubview:self.buttonWrapper];
    
    [self.random addTarget:self action:@selector(onRandom) forControlEvents:UIControlEventTouchUpInside];
    [self.set addTarget:self action:@selector(onSet) forControlEvents:UIControlEventTouchUpInside];
    [self.add addTarget:self action:@selector(onAdd) forControlEvents:UIControlEventTouchUpInside];
    [self.remove addTarget:self action:@selector(onRemove) forControlEvents:UIControlEventTouchUpInside];
    [self.autoTest addTarget:self action:@selector(onTest:) forControlEvents:UIControlEventTouchUpInside];
    
    self.inputView = [[UITextField alloc] init];
    self.inputView.text = @"9,9,4,7,6";
    [self.view addSubview:self.inputView];
    [self test];
}

- (void)onTest:(UIButton *)sender {
    sender.selected = !sender.selected;
    [self test];
}

- (void)test {
    if (!self.autoTest.isSelected) {
        return;
    }
    
    [self onRandom];
    [self onSet];
    
    [self.tableView layoutIfNeeded];
    [[self.tableView visibleCells] enumerateObjectsUsingBlock:^(__kindof UITableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSIndexPath *path = [self.tableView indexPathForCell:obj];
        
        NSString *value = self.array[path.row];
        NSAssert([value isEqualToString:obj.textLabel.text], @"数据没刷新到位");
    }];
    
    [self performSelector:@selector(test) withObject:nil afterDelay:1];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGRect bounds = self.view.bounds;
    self.buttonWrapper.frame = CGRectMake(10, 10, bounds.size.width-20, 40);
    self.inputView.frame = CGRectMake(20, CGRectGetMaxY(self.buttonWrapper.frame), bounds.size.width - 40, 40);
    self.inputView.borderStyle = UITextBorderStyleRoundedRect;
    self.tableView.frame = UIEdgeInsetsInsetRect(bounds, UIEdgeInsetsMake(CGRectGetMaxY(self.inputView.frame), 0, 0, 0));
}

- (void)onRemove {
    [self.array removeObjectsInArray:[self.inputView.text componentsSeparatedByString:@","]];
}

- (void)onSet {
    [self.array setArray:[self.inputView.text componentsSeparatedByString:@","]];
}

- (void)onAdd {
    [self.array addObjectsFromArray:[self.inputView.text componentsSeparatedByString:@","]];
}

- (void)onRandom {
    NSInteger count = arc4random()%10 + 1;
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    
    for (int i = 0; i < count; i++) {
        [array addObject:@(arc4random()%10).stringValue];
    }
    self.inputView.text = [array componentsJoinedByString:@","];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.array.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"111" forIndexPath:indexPath];
    NSString *obj = self.array[indexPath.row];
    cell.textLabel.text = obj;
    return cell;
}

#pragma mark - UITableViewDelegate

#pragma mark - RGArrayChangeDelegate

- (void)changeArray:(nonnull RGArray *)array change:(nonnull RGArrayChange *)change {
    
    NSLog(@"%@", change);
    
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:change.deletionIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView insertRowsAtIndexPaths:change.insertionsIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView reloadRowsAtIndexPaths:change.modificationIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
}

@end
