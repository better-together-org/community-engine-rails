import consumer from 'channels/consumer';
import { createDebug } from 'better_together/debugger';

const createConversationSubscription = (conversationId) => {
  if (!conversationId) {
    throw new Error("A conversation ID is required to create a subscription.");
  }

  // Create debug instance from consumer's application if available
  const debug = createDebug(window.Stimulus);

  return consumer.subscriptions.create({ channel: "BetterTogether::ConversationsChannel", id: conversationId }, {
    connected() {
      debug.log(`Conversation channel connected for ID: ${conversationId}`);
    },
    received(data) {
      debug.log(data);
    }
  });
};

export { createConversationSubscription };
