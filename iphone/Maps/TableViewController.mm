#import "TableViewController.h"
#import "../../3party/Alohalytics/src/alohalytics_objc.h"

@implementation TableViewController

- (BOOL)prefersStatusBarHidden
{
  return NO;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self.navigationController.navigationBar setTranslucent:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
  [Alohalytics logEvent:@"$viewWillAppear" withValue:NSStringFromClass([self class])];
  [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [Alohalytics logEvent:@"$viewWillDisappear" withValue:NSStringFromClass([self class])];
  [super viewWillDisappear:animated];
}

@end
