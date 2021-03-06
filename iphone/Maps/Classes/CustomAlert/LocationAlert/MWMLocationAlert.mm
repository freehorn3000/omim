#import "MWMLocationAlert.h"
#import "MWMAlertViewController.h"
#import "Statistics.h"

static NSString * const kLocationAlertNibName = @"MWMLocationAlert";
static NSString * const kStatisticsEvent = @"Location Alert";

@implementation MWMLocationAlert

+ (instancetype)alert
{
  [[Statistics instance] logEvent:kStatAlert
                   withParameters:@{kStatName : kStatisticsEvent, kStatAction : kStatOpen}];
  MWMLocationAlert * alert = [[[NSBundle mainBundle] loadNibNamed:kLocationAlertNibName owner:nil options:nil] firstObject];
  [alert setNeedsCloseAlertAfterEnterBackground];
  return alert;
}

- (IBAction)settingsTap
{
  [[Statistics instance] logEvent:kStatAlert
                   withParameters:@{kStatName : kStatisticsEvent, kStatAction : kStatApply}];
  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
  [self close];
}

- (IBAction)closeTap
{
  [[Statistics instance] logEvent:kStatAlert
                   withParameters:@{kStatName : kStatisticsEvent, kStatAction : kStatClose}];
  [self close];
}

@end
