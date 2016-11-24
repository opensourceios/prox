/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

fileprivate enum UIMode {
    case collapsed, expanded
}

class PlaceDetailsDescriptionView: UIView {

    private let CollapseExpandSeconds = 1.0

    let horizontalMargin: CGFloat

    fileprivate var uiMode: UIMode = .collapsed
    var collapsedConstraints: [NSLayoutConstraint]!
    var expandedConstraints: [NSLayoutConstraint]!

    lazy var logoView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    lazy var label: UILabel = {
        let view = UILabel()
        view.font = Fonts.detailsViewDescriptionTitle
        return view
    }()

    // TODO: icon
    lazy var expandButton: UIImageView = UIImageView()

    lazy var expandableLabel: UILabel = {
        let view = UILabel()
        view.font = Fonts.detailsViewDescriptionText
        view.textColor = Colors.detailsViewCardSecondaryText
        view.numberOfLines = 0
        return view
    }()

    lazy var descriptionTitleView: HorizontalLineView = {
        let view = HorizontalLineView()
        view.backgroundColor = .clear
        view.color = Colors.detailsViewCardSeparator
        view.startX = 0.0
        view.startY = 0.0
        view.endY = 0.0
        return view
    }()

    init(labelText: String,
         icon: UIImage?,
         horizontalMargin: CGFloat) {
        self.horizontalMargin = horizontalMargin
        super.init(frame: .zero)

        logoView.image = icon
        label.text = labelText
        backgroundColor = .clear

        setupSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    lazy var expandableLabelHeightConstraint: NSLayoutConstraint = {
        return self.expandableLabel.heightAnchor.constraint(equalToConstant: 0)
    }()

    lazy var expandableLabelBottomConstraint: NSLayoutConstraint = {
        return self.expandableLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor)
    }()

    lazy var logoBottomConstraint: NSLayoutConstraint = {
        return self.logoView.bottomAnchor.constraint(equalTo: self.descriptionTitleView.bottomAnchor)
    }()

    private func setupSubviews() {
        addSubview(descriptionTitleView)
        var constraints = [descriptionTitleView.topAnchor.constraint(equalTo: topAnchor),
                           descriptionTitleView.leadingAnchor.constraint(equalTo: leadingAnchor),
                           descriptionTitleView.trailingAnchor.constraint(equalTo: trailingAnchor)]

        descriptionTitleView.addSubview(logoView)
        constraints += [logoView.leadingAnchor.constraint(equalTo: descriptionTitleView.leadingAnchor, constant: horizontalMargin),
                           logoView.widthAnchor.constraint(equalToConstant: 16),
                           logoView.heightAnchor.constraint(equalToConstant: 16),
                           logoView.topAnchor.constraint(equalTo: descriptionTitleView.topAnchor, constant: 20),
                           logoBottomConstraint]

        descriptionTitleView.addSubview(label)
        constraints += [label.centerYAnchor.constraint(equalTo: logoView.centerYAnchor),
                        label.leadingAnchor.constraint(equalTo: logoView.trailingAnchor, constant: horizontalMargin),
                        label.trailingAnchor.constraint(equalTo: expandButton.leadingAnchor, constant: -horizontalMargin)]

        descriptionTitleView.addSubview(expandButton)
        constraints += [expandButton.centerYAnchor.constraint(equalTo: logoView.centerYAnchor),
                        expandButton.trailingAnchor.constraint(equalTo: descriptionTitleView.trailingAnchor, constant: -horizontalMargin),
                        expandButton.widthAnchor.constraint(equalToConstant: 16),
                        expandButton.heightAnchor.constraint(equalToConstant: 16)]

        addSubview(expandableLabel)
        constraints += [expandableLabel.topAnchor.constraint(equalTo: descriptionTitleView.bottomAnchor),
                        expandableLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalMargin),
                        expandableLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalMargin),
                        expandableLabelHeightConstraint,
                        expandableLabelBottomConstraint]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    func didTap() {
        setExpandableView(isExpanded: uiMode == .collapsed)
    }

    func setExpandableView(isExpanded shouldExpand: Bool) {
        if shouldExpand {
            uiMode = .expanded
            expandableLabelHeightConstraint.isActive = false
            expandableLabelBottomConstraint.constant = -10
            logoBottomConstraint.constant = -20
        } else {
            uiMode = .collapsed
            expandableLabelBottomConstraint.constant = 0
            expandableLabelHeightConstraint.isActive = true
            logoBottomConstraint.constant = 0
        }

        setNeedsLayout()
    }
}
