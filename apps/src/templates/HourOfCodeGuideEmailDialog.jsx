import React, {useState} from 'react';
import cookies from 'js-cookie';
import PropTypes from 'prop-types';
import i18n from '@cdo/locale';
import Button from '@cdo/apps/templates/Button';
import AccessibleDialog from '@cdo/apps/templates/AccessibleDialog';
import analyticsReporter from '@cdo/apps/lib/util/AnalyticsReporter';
import {EVENTS} from '@cdo/apps/lib/util/AnalyticsConstants';
import {Heading1, Heading3} from '@cdo/apps/componentLibrary/typography';
import style from './hoc-guide-dialogue.module.scss';
import {isEmail} from '@cdo/apps/util/formatValidation';

function HourOfCodeGuideEmailDialog({isSignedIn, unitId}) {
  const [isOpen, setIsOpen] = useState(true);
  const [isMarketingChecked, setIsMarketingChecked] = useState(false);
  const [isSendInProgress, setIsSendInProgress] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');

  const onClose = () => {
    cookies.set('HourOfCodeGuideEmailDialogSeen', 'true', {
      expires: 90,
      path: '/',
    });
    setIsOpen(false);
  };

  const reportAndNotifyOfEmailSend = () => {
    analyticsReporter.sendEvent(EVENTS.GUIDE_SENT_EVENT, {
      isSignedIn: isSignedIn,
    });
    alert(i18n.emailRequestSubmitted());
  };

  const validateAndSave = () => {
    // Only validate inputs for signed out users
    if (!isSignedIn && !isEmail(email)) {
      alert(i18n.censusInvalidEmail());
      return;
    }
    if (!isSignedIn && !name) {
      alert(i18n.censusRequired());
      return;
    }
    setIsSendInProgress(true);
    const potential_teacher_data = {
      name: name,
      email: email,
      receives_marketing: isMarketingChecked,
      script_id: unitId,
    };
    fetch('/potential_teachers', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(potential_teacher_data),
    })
      .then(() => {
        reportAndNotifyOfEmailSend();
        onClose();
      })
      .catch(err => {
        setIsSendInProgress(false);
        alert(i18n.unexpectedError());
        console.error(err);
      });
  };

  const bodyText = isSignedIn
    ? i18n.weHaveEverything()
    : i18n.signUpToReceiveGuide();

  const emailGuideButtonText = isSignedIn
    ? i18n.emailMeAGuide()
    : i18n.getGuideContinue();

  const continueWithoutEmailButtonText = isSignedIn
    ? i18n.continueToActivity()
    : i18n.continueWithoutGuide();

  return (
    <div>
      {isOpen && (
        <AccessibleDialog styles={style} onClose={onClose}>
          <div tabIndex="0">
            <Heading1>{i18n.welcomeToDanceParty()}</Heading1>
          </div>
          <div className={style.middle}>
            <Heading3>{i18n.learnHowToHost()}</Heading3>
            {bodyText}
            {!isSignedIn && (
              <div>
                <label className={style.typographyLabel}>
                  {i18n.yourNameCaps() + '*'}
                  <input
                    required
                    type="text"
                    id="uitest-hoc-guide-name"
                    className={style.classNameTextField}
                    value={name}
                    onChange={e => setName(e.target.value)}
                  />
                </label>
                <label className={style.typographyLabel}>
                  {i18n.yourEmailCaps() + '*'}
                  <input
                    required
                    type="text"
                    id="uitest-hoc-guide-email"
                    className={style.classNameTextField}
                    value={email}
                    onChange={e => setEmail(e.target.value)}
                  />
                </label>
                <label className={style.label}>
                  <input
                    checked={isMarketingChecked}
                    className={style.box}
                    type="checkbox"
                    id="uitest-receive-updates-checkbox"
                    onChange={() => {
                      setIsMarketingChecked(!isMarketingChecked);
                    }}
                  />
                  {i18n.receiveFutureUpdates()}
                </label>
              </div>
            )}
          </div>
          <div className={style.buttonsBottom}>
            <Button
              id="uitest-no-email-guide"
              text={continueWithoutEmailButtonText}
              onClick={onClose}
              color={Button.ButtonColor.white}
            />
            <Button
              id="uitest-email-guide"
              text={isSendInProgress ? i18n.inProgress() : emailGuideButtonText}
              onClick={validateAndSave}
              color={Button.ButtonColor.brandSecondaryDefault}
              disabled={isSendInProgress}
            />
          </div>
        </AccessibleDialog>
      )}
    </div>
  );
}

HourOfCodeGuideEmailDialog.propTypes = {
  isSignedIn: PropTypes.bool.isRequired,
  unitId: PropTypes.number.isRequired,
};

export const UnconnectedHourOfCodeGuideEmailDialog = HourOfCodeGuideEmailDialog;

export default HourOfCodeGuideEmailDialog;
