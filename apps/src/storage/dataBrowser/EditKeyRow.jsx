/** @overview Component for editing a key/value pair row. */
import FirebaseStorage from '../firebaseStorage';
import PropTypes from 'prop-types';
import React from 'react';
import PendingButton from '../../templates/PendingButton';
import {castValue, displayableValue, editableValue} from './dataUtils';
import dataStyles from './data-styles.module.scss';
import classNames from 'classnames';
import msg from '@cdo/locale';

const INITIAL_STATE = {
  isDeleting: false,
  isEditing: false,
  isSaving: false,
  newValue: '',
};

class EditKeyRow extends React.Component {
  static propTypes = {
    keyName: PropTypes.string.isRequired,
    value: PropTypes.any,
    showError: PropTypes.func.isRequired,
    hideError: PropTypes.func.isRequired,
  };

  state = {...INITIAL_STATE};

  componentDidMount() {
    this.isMounted_ = true;
  }

  componentWillUnmount() {
    this.isMounted_ = false;
  }

  handleChange = event => this.setState({newValue: event.target.value});

  handleEdit = () =>
    this.setState({
      isEditing: true,
      newValue: editableValue(this.props.value),
    });

  handleSave = () => {
    this.props.hideError();
    try {
      this.setState({isSaving: true});
      const newValue = castValue(
        this.state.newValue,
        /* allowUnquotedStrings */ false
      );
      FirebaseStorage.setKeyValue(
        this.props.keyName,
        newValue,
        this.resetState,
        msg => console.warn(msg)
      );
    } catch (e) {
      this.setState({isSaving: false});
      this.props.showError();
    }
  };

  resetState = () => {
    // Deleting a key/value pair could cause this component to become unmounted.
    if (this.isMounted_) {
      this.setState(INITIAL_STATE);
    }
  };

  handleDelete = () => {
    this.setState({isDeleting: true});
    FirebaseStorage.deleteKeyValue(this.props.keyName, this.resetState, msg =>
      console.warn(msg)
    );
  };

  handleKeyUp = event => {
    if (event.key === 'Enter') {
      this.handleSave();
    } else if (event.key === 'Escape') {
      this.setState(INITIAL_STATE);
    }
  };

  render() {
    return (
      <tr className={classNames(dataStyles.row, 'uitest-kv-table-row')}>
        <td className={dataStyles.cell}>
          {JSON.stringify(this.props.keyName)}
        </td>
        <td className={dataStyles.cell}>
          {this.state.isEditing ? (
            <input
              className={dataStyles.input}
              value={this.state.newValue || ''}
              onChange={this.handleChange}
              onKeyUp={this.handleKeyUp}
            />
          ) : (
            displayableValue(this.props.value)
          )}
        </td>
        <td className={classNames(dataStyles.cell, dataStyles.editButton)}>
          {!this.state.isDeleting &&
            (this.state.isEditing ? (
              <PendingButton
                isPending={this.state.isSaving}
                onClick={this.handleSave}
                pendingText={msg.saving()}
                className={classNames(
                  dataStyles.button,
                  dataStyles.buttonBlue,
                  dataStyles.buttonBlueSave
                )}
                text={msg.save()}
              />
            ) : (
              <button
                type="button"
                className={classNames(
                  dataStyles.button,
                  dataStyles.buttonWhite,
                  dataStyles.buttonWhiteEdit
                )}
                onClick={this.handleEdit}
              >
                {msg.edit()}
              </button>
            ))}

          {!this.state.isSaving && (
            <PendingButton
              isPending={this.state.isDeleting}
              onClick={this.handleDelete}
              pendingStyle={{float: 'right'}}
              pendingText={msg.deletingWithEllipsis()}
              className={classNames(dataStyles.button, dataStyles.buttonRed)}
              text={msg.delete()}
            />
          )}
        </td>
      </tr>
    );
  }
}

export default EditKeyRow;
