require_relative '../i18n_script_utils'

module I18n
  module Utils
    class SyncInBase
      class << self
        def perform
          new.send(:perform)
        end
      end

      def perform
        progress_bar = I18nScriptUtils.create_progress_bar(title: self.class.name)
        progress_bar.start
        process
        progress_bar.finish
      end

      def process
        proc {raise NotImplementedError}
      end
    end
  end
end
