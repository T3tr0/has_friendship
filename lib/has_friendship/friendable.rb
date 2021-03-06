module HasFriendship
  module Friendable

    def friendable?
      false
    end

    def has_friendship
      class_eval do
        has_many :friendships, as: :friendable,
                 class_name: "HasFriendship::Friendship", dependent: :destroy

        has_many :blocked_friends,
                  -> { where friendships: { status: 'blocked' } },
                  through: :friendships,
                  source: :friend

        has_many :friends,
                  -> { where friendships: { status: 'accepted' } },
                  through: :friendships

        has_many :requested_friends,
                  -> { where friendships: { status: 'requested' } },
                  through: :friendships,
                  source: :friend

        has_many :pending_friends,
                  -> { where friendships: { status: 'pending' } },
                  through: :friendships,
                  source: :friend

        def self.friendable?
          true
        end
      end

      include HasFriendship::Friendable::InstanceMethods
      include HasFriendship::Extender
    end

    module InstanceMethods

      def friend_request(friend)
        unless self == friend || HasFriendship::Friendship.exist?(self, friend)
          transaction do
            HasFriendship::Friendship.create_relation(self, friend, status: 'pending')
            HasFriendship::Friendship.create_relation(friend, self, status: 'requested')
          end
        end
      end

      def accept_request(friend)
        on_relation_with(friend) do |one, other|
          HasFriendship::Friendship.find_unblocked_friendship(one, other)
                                   .update(status: 'accepted')
        end
      end

      def decline_request(friend)
        on_relation_with(friend) do |one, other|
          HasFriendship::Friendship.find_unblocked_friendship(one, other).destroy
        end
      end

      alias_method :remove_friend, :decline_request

      def block_friend(friend)
        on_relation_with(friend) do |one, other|
          HasFriendship::Friendship.find_unblocked_friendship(one, other)
                                   .update(status: 'blocked', blocker_id: self.id)
        end
      end

      def unblock_friend(friend)
        return unless has_blocked(friend)
        on_relation_with(friend) do |one, other|
          HasFriendship::Friendship.find_blocked_friendship(one, other).destroy
        end
      end

      def on_relation_with(friend)
        transaction do
          yield(self, friend)
          yield(friend, self)
        end
      end

      def friends_with?(friend)
        HasFriendship::Friendship.find_relation(self, friend, status: 'accepted').any?
      end

      private

      def has_blocked(friend)
        HasFriendship::Friendship.find_one_side(self, friend).blocker_id == self.id
      end
    end
  end
end
