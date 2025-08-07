import consumer from 'channels/consumer';

const createConversationSubscription = (conversationId) => {
  if (!conversationId) {
    throw new Error("A conversation ID is required to create a subscription.");
  }

  return consumer.subscriptions.create({ channel: "BetterTogether::ConversationsChannel", id: conversationId }, {
    connected() {
      console.log(`Conversation channel connected for ID: ${conversationId}`);
    },
    received(data) {
      console.log(data);
    }
  });
};

export { createConversationSubscription };
