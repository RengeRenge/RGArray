# RGArray
RGArray inherit NSMutableArray, which could make a callback for the change of internal elements (insert, delete, replace, sort), including a certain change position

## Installation
Add via [CocoaPods](http://cocoapods.org) by adding this to your Podfile:

```ruby
pod 'RGArray'
```

## Usage
### Import
```objective-c
#import <RGArray/RGArray.h>
```

### RGArrayChangeDelegate

```objective-c
@interface ViewController () <UITableViewDataSource, UITableViewDelegate, RGArrayChangeDelegate>
@property (nonatomic, strong) RGArray <NSString *> *array;
@end
  
- (void)init {
  self.array = [RGArray arrayWithObjects:@"1", @"6", @"4", nil];
  [self.array addDelegate:self];
}

#pragma mark - RGArrayChangeDelegate

- (void)changeArray:(nonnull RGArray *)array change:(nonnull RGArrayChange *)change {
  NSLog(@"%@", change);
  [self.tableView beginUpdates];
  [self.tableView deleteRowsAtIndexPaths:change.deletionIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
  [self.tableView insertRowsAtIndexPaths:change.insertionsIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
  [self.tableView reloadRowsAtIndexPaths:change.modificationIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
  [self.tableView endUpdates];
}
```

#### callback step-by-step

Sometimes, we cannot use "reloadRowsAtIndexPaths" to refresh the list, because when the list has a selected state, the selected state will be lost after refreshing.

At this time, you need to take out a specific cell for modification.

```objective-c
self.array.changeByStep = YES;
```

```objective-c
#pragma mark - RGArrayChangeDelegate

- (void)changeArray:(RGArray *)array change:(RGArrayChange *)change {
  NSLog(@"change: %@", change);
  if (change.deletions.count || change.insertions.count) {
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:change.deletionIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView insertRowsAtIndexPaths:change.insertionsIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
  } else {
    [change.modificationIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:obj];
      if (cell) {
        [self configCell:cell withObj:array[obj.row]];
      }
    }];
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TableViewCellID" forIndexPath:indexPath];
  NSString *obj = self.array[indexPath.row];
  [self configCell:cell withObj:obj];
  return cell;
}

- (void)configCell:(UITableViewCell *)cell withObj:(NSString *)obj {
  cell.textLabel.text = obj;
}
```

⚠️ In this case, if you don’t use stepwise Callback, it will cause some exceptions in the list.

### Set Compare Rule For elements

- set special rule for a array

```objective-c
[self.array setEqualRule:^BOOL(NSString * _Nonnull obj, NSString * _Nonnull other) {
	return [obj isEqualToString:other];
}];
[self.array setModifyRule:^BOOL(NSString * _Nonnull old, NSString * _Nonnull young) {
  return ![old isEqualToString:young];
}];
```

- implement RGChangeProtocol for elements
```objective-c
#pragma mark - RGChangeProtocol

- (BOOL)rg_arrayObjIsEqual:(id)object {
    if ([object isKindOfClass:self.class]) {
        return [NSString rg_equalString:self.iotId toString:[object iotId]];
    }
    return NO;
}

- (BOOL)rg_arrayObjHasModification:(id)old {
    if ([old isKindOfClass:self.class]) {
        BOOL equal = self.status == [old status] &&
        [NSString rg_equalString:self.nickName toString:[old nickName]];
        return !equal;
    }
    return NO;
}
```

### Demo

- Simple Case

  ![1](https://user-images.githubusercontent.com/14158970/80349553-ffbe5f80-88a1-11ea-889e-ccc5535052e6.png)

- Complex Case

  generate a new array randomly
  
  ![2](https://user-images.githubusercontent.com/14158970/80348683-c0434380-88a0-11ea-8ec3-7292c3cec8d3.png)

