import 'package:flutter/material.dart';
import 'package:verbix/widgets/feedback_popup.dart';

class FeedbackService {
  static void showFeedbackPopup({
    required BuildContext context,
    required FeedbackState state,
    required VoidCallback onContinue,
    String? customHeading,
    String? customMessage,
  }) {
    String heading;
    String message;

    switch (state) {
      case FeedbackState.correct:
        heading = customHeading ?? 'Correct!';
        message = customMessage ?? 'Well done! Your answer is correct.';
        break;
      case FeedbackState.wrong:
        heading = customHeading ?? 'Try Again';
        message = customMessage ?? 'Your answer is incorrect. Keep practicing!';
        break;
      case FeedbackState.noText:
        heading = customHeading ?? 'No Text Detected';
        message =
            customMessage ?? 'I couldn\'t read your answer. Please try again.';
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FeedbackPopup(
          state: state,
          heading: heading,
          message: message,
          onContinue: () {
            Navigator.of(context).pop();
            onContinue();
          },
        );
      },
    );
  }
}
