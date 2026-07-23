use crate::domain::SubscriberEmail;
use crate::domain::SubscriberName;
use crate::routes::FormData;

pub struct NewSubscriber {
    pub email: SubscriberEmail,
    pub name: SubscriberName,
}
