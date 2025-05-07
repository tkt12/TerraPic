from django import forms
from allauth.account.forms import SignupForm

class CustomSignupForm(SignupForm):
    name = forms.CharField(max_length=100, label='名前')
    profile_image = forms.ImageField(required=False, label='プロフィール画像')
    
    def __init__(self, *args, **kwargs):
        super(CustomSignupForm, self).__init__(*args, **kwargs)
        self.fields['username'].label = 'ユーザーID'  # Change label for username field

    def save(self, request):
        user = super(CustomSignupForm, self).save(request)
        user.name = self.cleaned_data['name']
        if self.cleaned_data['profile_image']:
            user.profile_image = self.cleaned_data['profile_image']
        user.save()
        return user