from django.shortcuts import render

# Create your views here.
def index(request):
    return render(request, '<h1>I am not ready!</h1>')